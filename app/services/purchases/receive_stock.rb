# frozen_string_literal: true

module Purchases
  class ReceiveStock
    def self.call(item:, data:)
      new(item:, data:).call
    end

    def initialize(item:, data:)
      @item = item
      @data = data
    end

    def call
      validate_tracking!
      inventory = find_inventory
      lot = create_lot(inventory)
      create_serials(lot)
      Inventories::ApplyMovement.call(
        inventory:, quantity: @item.accepted_quantity, kind: 'receipt',
        user: @item.goods_receipt.received_by, source: @item, inventory_lot: lot
      )
    end

    private

    def product
      @item.purchase_order_item.product
    end

    def find_inventory
      receipt = @item.goods_receipt
      Inventory.find_or_create_by!(organization: receipt.organization, branch: receipt.branch, product:)
    end

    def serial_numbers
      @serial_numbers ||= Array(@data[:serial_numbers])
                          .flat_map { |value| value.to_s.split(/[\s,;]+/) }.compact_blank
    end

    def validate_tracking!
      tracking = product.tracking_mode
      raise ArgumentError, 'Lot number required' if tracking == 'lot' && @item.lot_code.blank?

      validate_serial_tracking! if tracking == 'serial'
      return unless @item.expires_on && @item.expires_on < Date.current

      raise ArgumentError, 'Expired merchandise cannot be received into available stock'
    end

    def validate_serial_tracking!
      expected = @item.accepted_quantity
      valid = expected.frac.zero? && serial_numbers.size == expected.to_i &&
              serial_numbers.uniq.size == serial_numbers.size

      raise ArgumentError, 'Serial count must match accepted units' unless valid
    end

    def create_lot(inventory)
      inventory.inventory_lots.create!(
        organization: inventory.organization, goods_receipt_item: @item,
        code: "#{@item.lot_code.presence || 'RCV'}-#{@item.id}", expires_on: @item.expires_on,
        status: :available, quantity: @item.accepted_quantity
      )
    end

    def create_serials(lot)
      return if serial_numbers.empty?

      serial_numbers.each do |number|
        lot.inventory_serials.create!(organization: lot.organization, serial_number: number)
      end
    end
  end
end
