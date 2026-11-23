# frozen_string_literal: true

module Admin
  class PriceListsController < CommercialCatalogController
    private

    def resource_class = PriceList
    def include_lookup_cost? = policy(PriceList).view_margin?
    def page_records(scope) = scope

    def detail_scope
      commercial_scope.preload(price_list_items: [:product_variant, :product_presentation,
                                                  { product: %i[product_variants product_presentations] }])
    end

    def prepare_index(scope)
      items = PriceListItem.where(organization: current_organization)
      @product_counts = items.where(price_list: @records).group(:price_list_id).distinct.count(:product_id)
      matches = scope.unscope(:order)
      @coverage_metrics = { products: items.where(price_list: matches).distinct.count(:product_id),
                            currencies: matches.distinct.count(:currency) }
    end

    def prepare_show
      super
      return unless policy(@record).history?

      rows = PriceListItem.with_deleted.where(organization: current_organization, price_list: @record)
      @price_history = PriceChangeEvent.where(organization: current_organization, price_list_item_id: rows.select(:id))
                                       .preload(:product, :actor).order(created_at: :desc, id: :desc).limit(50)
    end

    def persist_record
      attributes = record_params
      CommercialSubmittedReferences.new(current_organization, attributes[:price_list_items_attributes])
                                   .validate!(product_id: Product, product_variant_id: ProductVariant,
                                              product_presentation_id: ProductPresentation)
      Products::SavePriceList.new(list: @record, actor: current_user, attributes:,
                                  reason: params.permit(:price_change_reason)[:price_change_reason]).call
    end

    def record_params
      params.expect(price_list: [:name, :currency, :customer_segment, :starts_at, :ends_at, :default_list, :priority,
                                 { price_list_items_attributes: [
                                   %i[id _destroy product_id product_variant_id product_presentation_id
                                      price starts_at ends_at minimum_quantity]
                                 ] }])
    end
  end
end
