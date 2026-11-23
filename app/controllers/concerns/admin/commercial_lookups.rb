# frozen_string_literal: true

module Admin
  module CommercialLookups
    PREVIEW_FIELDS = %i[product_id variant_id presentation_id quantity at customer_reference customer_segment].freeze

    def products_lookup
      results = CommercialProductLookup.new(organization: current_organization, term: params.permit(:q)[:q],
                                            currency: base_currency, include_cost: include_lookup_cost?).call
      render json: { products: results }
    end

    private

    def authorize_lookup
      permissions = policy(resource_class)
      return if permissions.index? || permissions.show? || permissions.create? || permissions.update?

      raise Pundit::NotAuthorizedError
    end

    def render_commercial_preview
      output = CommercialPreview.new(record: @record, organization: current_organization, inputs: preview_params).call
      output[:promotion] = nil unless policy(Promotion).show?
      output[:price_list] = nil unless policy(PriceList).show?
      render json: output
    rescue ActiveRecord::RecordNotFound
      render json: { error: t('admin.catalog_design.invalid_quote') }, status: :not_found
    rescue ArgumentError
      render json: { error: t('admin.catalog_design.invalid_quote') }, status: :unprocessable_content
    end

    def preview_params
      inputs = params.permit(*PREVIEW_FIELDS)
      raise ArgumentError unless inputs.keys.size == params.slice(*PREVIEW_FIELDS).keys.size

      inputs
    end
  end
end
