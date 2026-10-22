# frozen_string_literal: true

module Purchases
  class Workflow
    TRANSITIONS = {
      'draft' => { submit: 'pending_approval', cancel: 'cancelled' },
      'pending_approval' => { approve: 'approved', reject: 'rejected', cancel: 'cancelled' },
      'approved' => { dispatch: 'ordered', cancel: 'cancelled' },
      'ordered' => { cancel: 'cancelled', close: 'closed' },
      'partially_received' => { close: 'closed' },
      'received' => { close: 'closed' }
    }.freeze

    def self.call(order:, action:, user:, notes: nil)
      new(order:, action:, user:, notes:).call
    end

    def initialize(order:, action:, user:, notes:)
      @order = order
      @action = action.to_sym
      @user = user
      @notes = notes
    end

    def call
      @order.supplier.with_lock do
        @order.with_lock do
          raise ArgumentError, 'An order with receipts cannot be cancelled' if cancelled_received_order?

        state = TRANSITIONS.fetch(@order.status, {})[@action]
        raise ArgumentError, 'Invalid order status transition' unless state

        validate_transition!
        ensure_available_supplier! if @action.in?(%i[submit approve dispatch])
        update_status!(state)
        record_decision!(state) if @action.in?(%i[approve reject])
          @order
        end
      end
    end

    def self.submit_request!(request)
      request.with_lock do
        raise ArgumentError, 'Request is not a draft' unless request.draft?
        raise ArgumentError, 'Request needs items' if request.purchase_request_items.empty?

        request.update!(status: :submitted, submitted_at: Time.current)
      end
    end

    def self.decide_request!(request, status:, user:)
      request.with_lock do
        raise ArgumentError, 'Request must be submitted' unless request.submitted?
        raise ArgumentError, 'Unsupported request decision' unless status.in?(%w[approved rejected])

        raise ArgumentError, 'Requester cannot approve or reject own request' if request.requested_by_id == user.id

        request.update!(status:)
      end
    end

    private

    def validate_transition!
      raise ArgumentError, 'Purchase order needs items' if @action == :submit && @order.purchase_order_items.empty?
      if @action == :close && !@order.goods_receipts.exists?
        raise ArgumentError, 'Cannot close before receiving merchandise'
      end
      raise ArgumentError, 'Requester cannot approve or reject own order' if self_decision?
    end

    def ensure_available_supplier!
      supplier = @order.supplier
      raise ArgumentError, 'Supplier is unavailable' unless supplier&.active? && supplier.deleted_at.nil?
    end

    def cancelled_received_order?
      @action == :cancel && @order.goods_receipts.exists?
    end

    def self_decision?
      @action.in?(%i[approve reject]) && @order.requested_by_id == @user.id
    end

    def update_status!(state)
      values = { status: state }
      values[:approved_by] = @user if @action == :approve
      values[:approved_at] = Time.current if @action == :approve
      values[:cancelled_at] = Time.current if @action == :cancel
      @order.update!(values)
    end

    def record_decision!(state)
      @order.purchase_approvals.create!(
        organization: @order.organization, decided_by: @user, decision: state, notes: @notes
      )
    end
  end
end
