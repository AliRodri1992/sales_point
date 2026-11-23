# frozen_string_literal: true

module Admin
  class PromotionsController < CommercialCatalogController
    CONDITION_FIELDS = %i[id _destroy kind product_id category_id quantity amount customer_segment].freeze

    def categories_lookup
      term = "%#{Category.sanitize_sql_like(params.permit(:q)[:q].to_s.strip.first(100))}%"
      matches = current_organization.categories.available.where('name ILIKE :q OR code ILIKE :q', q: term)
      render json: { categories: matches.order(:name, :id).limit(20).as_json(only: %i[id name code]) }
    end

    private

    def resource_class = Promotion
    def include_lookup_cost? = false

    def page_records(scope)
      scope.select('promotions.*', "#{CommercialCatalogQuery::USAGE_COUNT_SQL} AS usage_count")
           .preload(:promotion_benefits, promotion_conditions: %i[product category])
    end

    def detail_scope
      commercial_scope.preload(:promotion_benefits, promotion_conditions: %i[product category])
    end

    def prepare_index(_scope)
      @selected_category = current_organization.categories.find_by(id: params.permit(:category_id)[:category_id])
      @usage_counts = @records.index_by(&:id).transform_values(&:usage_count)
    end

    def prepare_show
      super
      @usage_counts = { @record.id => @record.usage_count }
    end

    def render_form(status = :ok)
      prepare_form
      super
    end

    def prepare_form
      return unless policy(PriceList).index?

      lists = current_organization.price_lists.with_deleted
      @target_lists = lists.where(status: 'active', deleted_at: nil).or(lists.where(id: @record.price_list_id))
                           .order(:name, :id)
    end

    def persist_record
      attributes = record_params
      CommercialSubmittedReferences.new(current_organization, attributes[:promotion_conditions_attributes])
                                   .validate!(product_id: Product, category_id: Category)
      @record.assign_attributes(attributes)
      @record.save!
    rescue ActiveRecord::RecordInvalid
      false
    end

    def record_params
      permitted = params.expect(promotion: [:name, :currency, :starts_at, :ends_at, :usage_limit, :customer_limit,
                                            :price_list_id, :priority, :maximum_discount, :combination_mode,
                                            { promotion_conditions_attributes: [CONDITION_FIELDS],
                                              promotion_benefits_attributes: [%i[id _destroy kind value]] }])
      if permitted[:price_list_id].present?
        authorize PriceList, :index?
        current_organization.price_lists.with_deleted.find(permitted[:price_list_id])
      end
      permitted.delete(:price_list_id) unless policy(PriceList).index?
      permitted
    end
  end
end
