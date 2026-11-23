# frozen_string_literal: true

module Products
  class ListPriceCost
    def initialize(list)
      @list = list
    end

    def changed_below_cost?(item)
      changed = item.new_record? || item.will_save_change_to_price? || extended_period?(item) || extended_period?(@list)
      changed && below_cost?(item)
    end

    def below_cost?(item)
      return false unless item.price && item.product&.cost
      return false unless item.product.organization_id == @list.organization_id && @list.currency == base_currency

      units = item.product_presentation&.units || 1
      item.price.round(precision, :half_up) < item.product.cost * units
    end

    private

    def extended_period?(record)
      previous_start = record.starts_at_in_database
      previous_end = record.ends_at_in_database
      (previous_start && (!record.starts_at || record.starts_at < previous_start)) ||
        (previous_end && (!record.ends_at || record.ends_at > previous_end))
    end

    def base_currency
      @base_currency ||= @list.organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def precision
      @precision ||= Currency.with_deleted.where(code: @list.currency).pick(:decimal_places) || 2
    end
  end
end
