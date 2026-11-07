# frozen_string_literal: true

module Admin
  class PriceListsController < CommercialCatalogController
    private

    def resource_class = PriceList

    def persist_record
      Products::SavePriceList.new(list: @record, actor: current_user, attributes: record_params,
                                  reason: params[:price_change_reason]).call
    end

    def record_params
      params.expect(price_list: [:name, :code, :currency, :customer_segment, :status, :starts_at, :ends_at,
                                 { price_list_items_attributes: [
                                   %i[id product_id product_variant_id product_presentation_id price starts_at ends_at]
                                 ] }])
    end
  end
end
