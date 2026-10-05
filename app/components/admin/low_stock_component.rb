# frozen_string_literal: true

module Admin
  class LowStockComponent < ViewComponent::Base
    Product = Data.define(
      :name,
      :sku,
      :quantity,
      :quantity_color
    )

    PRODUCTS = [
      Product.new(
        name: 'Cafe Americano 500g',
        sku: 'CAF-500',
        quantity: 2,
        quantity_color: 'text-red-600'
      ),
      Product.new(
        name: 'Leche Entera 1L',
        sku: 'LEC-001',
        quantity: 5,
        quantity_color: 'text-amber-600'
      ),
      Product.new(
        name: 'Azucar 1kg',
        sku: 'AZU-001',
        quantity: 7,
        quantity_color: 'text-amber-600'
      )
    ].freeze

    private

    def alert_count
      8
    end

    def products
      PRODUCTS
    end
  end
end
