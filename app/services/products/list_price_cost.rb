# frozen_string_literal: true

module Products
  class ListPriceCost
    def initialize(list)
      @list = list
    end

    def below_cost?(item)
      return false unless item.price && item.product&.cost
      return false unless item.product.organization_id == @list.organization_id && @list.currency == base_currency

      units = item.product_presentation&.units || 1
      item.price.round(precision, :half_up) < item.product.cost * units
    end

    private

    def base_currency
      @base_currency ||= @list.organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def precision
      @precision ||= Currency.with_deleted.where(code: @list.currency).pick(:decimal_places) || 2
    end
  end
end
