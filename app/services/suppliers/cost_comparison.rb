# frozen_string_literal: true

module Suppliers
  class CostComparison
    def self.call(organization:, product:)
      return [] unless product.organization_id == organization.id

      offers = SupplierProduct.available
                              .joins(:supplier).merge(Supplier.available)
                              .includes(:supplier, :currency, product: :preferred_supplier)
                              .where(organization:, product:)
      comparison = offers.map do |offer|
        {
          offer:,
          currency: offer.currency.code,
          cost_per_unit: offer.unit_cost,
          lead_time_days: offer.lead_time_days,
          preferred: offer.preferred?
        }
      end
      comparison.sort_by { |result| [result[:currency], result[:cost_per_unit], result[:lead_time_days]] }
    end
  end
end
