# frozen_string_literal: true

module Admin
  module ProductPricingPreview
    def render_price_quote
      set_product
      authorize @product, :show?
      result = product_quote
      render json: { unit_price: result.unit_price.to_s('F'), discount: result.discount.to_s('F'),
                     total: result.total.to_s('F'), currency: result.currency, promotion: result.promotion&.name }
    rescue ArgumentError => e
      message_key = case e.message
                    when 'Invalid price list' then 'admin.catalog_design.invalid_price_list'
                    when 'No price in the selected currency' then 'admin.catalog_design.price_currency_unavailable'
                    else 'admin.catalog_design.invalid_quote'
                    end
      render json: { error: t(message_key) }, status: :unprocessable_content
    end

    private

    def product_quote
      Products::Quote.new(product: @product, **quote_options).call
    end

    def quote_options
      { quantity: params[:quantity] || 1,
        variant: quote_option(@product.product_variants, :variant_id),
        presentation: quote_option(@product.product_presentations, :presentation_id),
        price_list: quote_option(current_organization.price_lists, :price_list_id),
        customer_segment: params[:customer_segment] }
    end

    def quote_option(scope, parameter)
      scope.find(params[parameter]) if params[parameter].present?
    end
  end
end
