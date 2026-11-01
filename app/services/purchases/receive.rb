# frozen_string_literal: true

module Purchases
  class Receive
    def self.call(order:, user:, idempotency_key:, entries:, **options)
      new(order:, user:, idempotency_key:, entries:, options:).call
    end

    def initialize(order:, user:, idempotency_key:, entries:, options:)
      @order = order
      @user = user
      @idempotency_key = idempotency_key
      @entries = entries
      @notes = options[:notes]
      @actual_costs = options.fetch(:actual_costs, {})
    end

    def call
      return existing if existing

      @order.with_lock do
        return existing if existing

        validate_order!
        receipt = create_receipt
        @entries.each { |entry| ReceiveLine.call(receipt:, data: entry.symbolize_keys) }
        Purchases::Costing.apply!(receipt)
        refresh_order_status!
        receipt
      end
    rescue ActiveRecord::RecordNotUnique
      existing || raise
    end

    private

    def existing
      return if @idempotency_key.blank?

      receipt = GoodsReceipt.find_by(organization: @order.organization, idempotency_key: @idempotency_key)
      return unless receipt

      different_order = receipt.purchase_order_id != @order.id
      raise ArgumentError, 'Operation key belongs to a different purchase order' if different_order

      if receipt.payload_digest.present? && receipt.payload_digest != payload_digest
        raise ArgumentError, 'Operation key cannot be reused with different receiving details'
      end

      receipt
    end

    def payload_digest
      @payload_digest ||= Digest::SHA256.hexdigest(
        JSON.generate(lines: canonical_entries, notes: @notes, actual_costs: @actual_costs)
      )
    end

    def canonical_entries
      @entries.map { |entry| entry.to_h.deep_stringify_keys.sort.to_h }
              .sort_by { |line| line['purchase_order_item_id'].to_s }
    end

    def validate_order!
      raise ArgumentError, 'Receipt needs a unique operation key' if @idempotency_key.blank?
      raise ArgumentError, 'Order must be sent before receiving' unless @order.receivable?
      raise ArgumentError, 'Receipt must contain items' if @entries.blank?
    end

    def create_receipt
      GoodsReceipt.create!(
        organization: @order.organization, branch: @order.branch,
        purchase_order: @order, received_by: @user, idempotency_key: @idempotency_key,
        received_at: Time.current, notes: @notes, payload_digest: payload_digest, **@actual_costs
      )
    end

    def refresh_order_status!
      complete = @order.purchase_order_items.all? { |item| @order.outstanding_quantity_for(item).zero? }
      @order.update!(status: complete ? :received : :partially_received)
    end
  end
end
