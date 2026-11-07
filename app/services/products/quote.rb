# frozen_string_literal: true

module Products
  class Quote
    Result = Struct.new(:unit_price, :quantity, :base_units, :subtotal, :discount, :total, :currency,
                        :promotion, :price_list_item, keyword_init: true)

    def initialize(product:, quantity: 1, **options)
      @product = product
      @quantity = BigDecimal(quantity.to_s, exception: false)
      @variant = options[:variant]
      @presentation = options[:presentation]
      @price_list = options[:price_list]
      @segment = options[:customer_segment]
      @customer = options[:customer_reference]
      @at = options.fetch(:at, Time.current)
    end

    def call
      validate_context!
      unit_price, item = effective_price
      subtotal = (unit_price * @quantity).round(2)
      raise ArgumentError, 'Line total exceeds the supported amount' if subtotal >= 10_000_000_000

      promotion, discount = best_promotion(subtotal)
      Result.new(unit_price:, quantity: @quantity, base_units: @quantity * presentation_units,
                 subtotal:, discount:, total: subtotal - discount, currency:, promotion:, price_list_item: item)
    end

    private

    def validate_context!
      raise ArgumentError, 'Invalid quantity' unless valid_quantity?
      raise ArgumentError, 'Inactive product' unless @product.active? && @product.deleted_at.nil?

      [@variant, @presentation].compact.each { |option| validate_option!(option) }
      validate_price_list! if @price_list
    end

    def valid_quantity?
      @quantity&.finite? && @quantity.positive? && @quantity <= 1_000_000 && @quantity == @quantity.round(6)
    end

    def validate_option!(option)
      valid = option.product_id == @product.id && option.organization_id == @product.organization_id
      raise ArgumentError, 'Invalid product option' unless valid && option.active? && option.deleted_at.nil?
    end

    def validate_price_list!
      valid = @price_list.organization_id == @product.organization_id && @price_list.active?
      valid &&= @price_list.deleted_at.nil? && effective?(@price_list)
      valid &&= @price_list.customer_segment.blank? || @price_list.customer_segment == @segment
      raise ArgumentError, 'Invalid price list' unless valid
    end

    def effective?(record)
      (!record.starts_at || record.starts_at <= @at) && (!record.ends_at || record.ends_at > @at)
    end

    def presentation_units
      @presentation&.units || BigDecimal('1')
    end

    def base_currency
      @base_currency ||= @product.organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def currency
      @price_list&.currency || base_currency
    end

    def base_price
      @product.price * presentation_units
    end

    def effective_price
      return [base_price, nil] unless @price_list

      item = matching_list_item
      raise ArgumentError, 'No price in the selected currency' if item.nil? && @price_list.currency != base_currency

      [item ? item.price : base_price, item]
    end

    def matching_list_item
      @price_list.price_list_items.effective_at(@at).find_by(product: @product, product_variant_id: @variant&.id,
                                                             product_presentation_id: @presentation&.id)
    end

    def best_promotion(subtotal)
      candidates = available_promotions.filter_map { |offer| eligible_discount(offer, subtotal) }
      candidates.max_by { |offer, discount| [discount, -offer.id] } || [nil, BigDecimal('0')]
    end

    def available_promotions
      Promotion.where(organization_id: @product.organization_id, status: 'active', currency:)
               .effective_at(@at).includes(:promotion_conditions, :promotion_benefits).order(:id)
    end

    def eligible_discount(offer, subtotal)
      context = { product: @product, quantity: @quantity * presentation_units, subtotal:,
                  segment: @segment, customer: @customer }
      return unless PromotionEligibility.new(offer, **context).eligible?

      discount = offer.promotion_benefits.map { |benefit| benefit.discount_for(subtotal) }.max || BigDecimal('0')
      [offer, discount] if discount.positive?
    end
  end
end
