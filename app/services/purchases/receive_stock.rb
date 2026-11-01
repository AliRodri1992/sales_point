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
      accepted_lot = create_lot(inventory, quantity: @item.accepted_quantity, status: :available)
      damaged_lot = create_lot(inventory, quantity: @item.damaged_quantity, status: :quarantined)
      create_serials(accepted_lot, accepted_serials)
      create_serials(damaged_lot, damaged_serials)

      return unless accepted_lot

      Inventories::ApplyMovement.call(
        inventory:, quantity: @item.accepted_quantity, kind: 'receipt',
        user: @item.goods_receipt.received_by, source: @item, inventory_lot: accepted_lot
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

    def accepted_serials
      @accepted_serials ||= split_serials(@data[:serial_numbers])
    end

    def damaged_serials
      @damaged_serials ||= split_serials(@data[:damaged_serial_numbers])
    end

    def split_serials(value)
      Array(value).flat_map { |entry| entry.to_s.split(/[\s,;]+/) }.compact_blank
    end

    def validate_tracking!
      tracking = product.tracking_mode
      raise ArgumentError, 'Lot number required' if tracking == 'lot' && @item.lot_code.blank?

      validate_serial_tracking! if tracking == 'serial'
      return unless @item.accepted_quantity.positive? && @item.expires_on && @item.expires_on < Date.current

      raise ArgumentError, 'Expired merchandise cannot be received into available stock'
    end

    def validate_serial_tracking!
      numbers = accepted_serials + damaged_serials
      return if serial_quantities_match? && numbers.uniq.size == numbers.size

      raise ArgumentError, 'Serial count must match accepted and damaged units'
    end

    def serial_quantities_match?
      valid_serial_quantity?(@item.accepted_quantity, accepted_serials) &&
        valid_serial_quantity?(@item.damaged_quantity, damaged_serials)
    end

    def valid_serial_quantity?(quantity, serials)
      quantity.frac.zero? && serials.size == quantity.to_i
    end

    def create_lot(inventory, quantity:, status:)
      return unless quantity.positive?

      base = @item.lot_code.presence || 'RCV'
      suffix = status == :quarantined ? '-DMG' : ''
      inventory.inventory_lots.create!(
        organization: inventory.organization, goods_receipt_item: @item,
        code: "#{base}-#{@item.id}#{suffix}", expires_on: @item.expires_on,
        status:, quantity:
      )
    end

    def create_serials(lot, serial_numbers)
      return unless lot

      serial_numbers.each do |number|
        lot.inventory_serials.create!(
          organization: lot.organization, serial_number: number,
          status: lot.quarantined? ? :quarantined : :available
        )
      end
    end
  end
end
