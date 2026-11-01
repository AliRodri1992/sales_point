# frozen_string_literal: true

module Purchases
  class BuildQuotationFromRequest
    def self.call(request:)
      raise ArgumentError, 'A purchase request must be approved' unless request.approved?

      quotation = PurchaseQuotation.new(organization: request.organization, purchase_request: request)
      request.purchase_request_items.each do |item|
        quotation.purchase_quotation_items.build(
          product: item.product, quantity: item.quantity, units_per_package: 1,
          unit_price: 0, discount_percent: 0, lead_time_days: 0
        )
      end
      quotation
    end
  end
end
