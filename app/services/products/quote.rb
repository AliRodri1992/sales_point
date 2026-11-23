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
      @promotion = options[:promotion]
      @segment = options[:customer_segment].presence
      @customer = options[:customer_reference]
      @at = options.fetch(:at, Time.current)
    end

    def call
      ActiveSupport::Notifications.instrument('promotions.quote') { calculate(preview: false) }
    end

    def preview
      ActiveSupport::Notifications.instrument('promotions.preview') { calculate(preview: true) }
    end

    private

    def calculate(preview:)
      validate_context!
      list = resolved_list(preview:)
      item = list_item_for(list) if list
      currency = list&.currency || base_currency
      precision = Currency.with_deleted.where(code: currency).pick(:decimal_places) || 2
      line = priced_line(item, currency, precision)
      apply_promotion(line, list:, precision:, selected: preview ? @promotion : nil)
    end

    def apply_promotion(line, list:, precision:, selected:)
      rules = LinePromotion.new(product: @product, quantity: line.base_units, subtotal: line.subtotal,
                                segment: @segment, customer: @customer)
      line.promotion, line.discount = rules.best(currency: line.currency, precision:, at: @at, list:, selected:)
      line.total = line.subtotal - line.discount
      line
    end

    def priced_line(item, currency, precision)
      unit_price = effective_price(item, currency).round(precision, :half_up)
      subtotal = (unit_price * @quantity).round(precision, :half_up)
      raise ArgumentError, 'Line total exceeds the supported amount' if subtotal >= 10_000_000_000

      Result.new(unit_price:, quantity: @quantity, base_units:, subtotal:, currency:, price_list_item: item)
    end

    def validate_context!
      raise ArgumentError, 'Invalid quantity' unless valid_quantity?
      raise ArgumentError, 'Inactive product' unless @product.active? && @product.deleted_at.nil?

      [@variant, @presentation].compact.each { |option| validate_option!(option) }
    end

    def valid_quantity?
      @quantity&.finite? && @quantity.positive? && @quantity <= 1_000_000 && @quantity == @quantity.round(6)
    end

    def validate_option!(option)
      valid = option.product_id == @product.id && option.organization_id == @product.organization_id
      raise ArgumentError, 'Invalid product option' unless valid && option.active? && option.deleted_at.nil?
    end

    def resolved_list(preview:)
      lists = PriceList.where(organization_id: @product.organization_id).effective_at(@at)
      return automatic_list(lists) unless @price_list

      statuses = preview ? %w[active draft] : ['active']
      selected = lists.where(status: statuses, customer_segment: [nil, @segment]).find_by(id: @price_list.id)
      selected || raise(ArgumentError, 'Invalid price list')
    end

    def automatic_list(lists)
      eligible = lists.where(status: 'active', currency: base_currency, id: matching_items.select(:price_list_id))
                      .order(priority: :desc, id: :asc)
      segment = eligible.find_by(customer_segment: @segment) if @segment
      segment || eligible.find_by(default_list: true, customer_segment: nil)
    end

    def list_item_for(list)
      matching_items.where(price_list: list).order(minimum_quantity: :desc, id: :asc).first
    end

    def matching_items
      PriceListItem.effective_at(@at).where(organization_id: @product.organization_id, product: @product,
                                            product_variant_id: @variant&.id,
                                            product_presentation_id: @presentation&.id)
                   .where(minimum_quantity: ..base_units)
    end

    def presentation_units
      @presentation&.units || BigDecimal('1')
    end

    def base_units
      @quantity * presentation_units
    end

    def base_currency
      @base_currency ||= @product.organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def effective_price(item, currency)
      return item.price if item
      raise ArgumentError, 'No price in the selected currency' unless currency == base_currency

      @product.price * presentation_units
    end
  end
end
