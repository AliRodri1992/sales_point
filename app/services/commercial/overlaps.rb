# frozen_string_literal: true

module Commercial
  class Overlaps
    LIMIT = 5

    def initialize(record, at: Time.current)
      @record = record
      @at = at
    end

    def call
      return [] if @record.ends_at && @record.ends_at <= @at

      scope = overlapping_windows
      scope = matching_products(scope) if @record.is_a?(PriceList)
      scope.order(priority: :desc, id: :asc).limit(LIMIT).to_a
    end

    private

    def overlapping_windows
      scope = @record.class.where(organization_id: @record.organization_id, currency: @record.currency,
                                  status: 'active').where.not(id: @record.id)
      scope = scope.where('ends_at IS NULL OR ends_at > ?', [@record.starts_at, @at].compact.max)
      return scope unless @record.ends_at

      scope.where('starts_at IS NULL OR starts_at < ?', @record.ends_at)
    end

    def matching_products(scope)
      product_ids = @record.price_list_items.select(:product_id)
      matching_lists = PriceListItem.where(organization_id: @record.organization_id, product_id: product_ids)
                                    .select(:price_list_id)
      scope = scope.where(id: matching_lists)
      return scope if @record.customer_segment.blank?

      scope.where(customer_segment: [nil, '', @record.customer_segment])
    end
  end
end
