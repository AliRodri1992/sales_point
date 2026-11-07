# frozen_string_literal: true

module Admin
  module ProductPricingPreview
    def render_price_quote
      set_product
      authorize @product, :show?
      result = product_quote
      render json: { unit_price: result.unit_price.to_s('F'), discount: result.discount.to_s('F'),
                     total: result.total.to_s('F'), currency: result.currency, promotion: result.promotion&.name }
    rescue ArgumentError
      render json: { error: t('admin.catalog_design.invalid_quote') }, status: :unprocessable_content
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
