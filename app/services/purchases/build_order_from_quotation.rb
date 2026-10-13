# frozen_string_literal: true

module Purchases
  class BuildOrderFromQuotation
    def self.call(quotation:, requested_by:)
      validate_quotation!(quotation)
      order = build_order(quotation, requested_by)
      quotation.purchase_quotation_items.each { |line| copy_line!(order, line) }
      order
    end

    def self.validate_quotation!(quotation)
      valid = quotation.accepted? && (quotation.valid_until.nil? || quotation.valid_until >= Date.current)
      raise ArgumentError, 'An accepted, unexpired quotation is required' unless valid
    end

    def self.build_order(quotation, user)
      PurchaseOrder.new(
        organization: quotation.organization, supplier: quotation.supplier,
        currency: quotation.currency, purchase_quotation: quotation,
        purchase_request: quotation.purchase_request,
        branch: quotation.purchase_request&.branch, requested_by: user
      )
    end

    def self.copy_line!(order, line)
      order.purchase_order_items.build(
        product: line.product, supplier_product: line.supplier_product,
        quantity: line.quantity, units_per_package: line.units_per_package,
        unit_price: line.unit_price, discount_percent: line.discount_percent
      )
    end

  end
end
