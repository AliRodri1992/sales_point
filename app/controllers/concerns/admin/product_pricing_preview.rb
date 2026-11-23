# frozen_string_literal: true

module Admin
  module ProductPricingPreview
    def render_price_quote
      set_product
      authorize @product, :show?
      render json: quote_payload(product_quote)
    rescue ActiveRecord::RecordNotFound
      render json: { error: t('admin.catalog_design.invalid_quote') }, status: :not_found
    rescue ActionController::ParameterMissing
      render json: { error: t('admin.catalog_design.invalid_quote') }, status: :bad_request
    rescue ArgumentError => e
      render json: { error: t(quote_error_key(e)) }, status: :unprocessable_content
    end

    private

    def quote_error_key(error)
      case error.message
      when 'Invalid price list' then 'admin.catalog_design.invalid_price_list'
      when 'No price in the selected currency' then 'admin.catalog_design.price_currency_unavailable'
      else 'admin.catalog_design.invalid_quote'
      end
    end

    def quote_payload(result)
      promotion = result.promotion
      { unit_price: result.unit_price.to_s('F'), discount: result.discount.to_s('F'),
        total: result.total.to_s('F'), currency: result.currency,
        promotion: promotion && policy(promotion).show? ? promotion.name : nil }
    end

    def product_quote
      Products::Quote.new(product: @product, **quote_options).call
    end

    def quote_options
      { quantity: quote_parameter(:quantity) || 1,
        variant: quote_option(@product.product_variants, :variant_id),
        presentation: quote_option(@product.product_presentations, :presentation_id),
        price_list: quote_price_list,
        customer_segment: quote_parameter(:customer_segment) }
    end

    def quote_price_list
      id = quote_parameter(:price_list_id)
      return if id.blank?

      authorize PriceList, :show?
      current_organization.price_lists.find(id)
    end

    def quote_option(scope, parameter)
      id = quote_parameter(parameter)
      scope.find(id) if id.present?
    end

    def quote_parameter(parameter)
      value = params[parameter]
      return value if value.nil? || (value.is_a?(String) && value.blank?)

      params.expect(parameter)
    end
  end
end
