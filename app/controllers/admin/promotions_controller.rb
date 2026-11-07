# frozen_string_literal: true

module Admin
  class PromotionsController < CommercialCatalogController
    private

    def resource_class = Promotion

    def record_params
      params.expect(promotion: [:name, :code, :currency, :status, :starts_at, :ends_at, :usage_limit, :customer_limit,
                                { promotion_conditions_attributes: [
                                    %i[id _destroy kind product_id category_id quantity amount customer_segment]
                                  ],
                                  promotion_benefits_attributes: [%i[id _destroy kind value]] }])
    end
  end
end
