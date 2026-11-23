# frozen_string_literal: true

class CommercialCatalogQuery
  SORT_COLUMNS = %w[name code currency starts_at ends_at created_at].freeze
  USAGE_COUNT_SQL = <<~SQL.squish.freeze
    (SELECT COUNT(*) FROM promotion_redemptions
      WHERE promotion_redemptions.promotion_id = promotions.id
        AND promotion_redemptions.organization_id = promotions.organization_id
        AND promotion_redemptions.deleted_at IS NULL)
  SQL

  def initialize(scope, filters, at: Time.current)
    @base = scope
    @filters = filters
    @at = at
  end

  def call
    scope = filter_status(filter_validity(search(@base), @filters[:validity]))
    scope = scope.where(currency: @filters[:currency]) if @filters[:currency].present?
    scope = promotion? ? filter_promotions(scope) : filter_lists(scope)
    direction = @filters[:direction] == 'desc' ? :desc : :asc
    column = SORT_COLUMNS.include?(@filters[:sort]) ? @filters[:sort] : 'name'
    scope.order(column => direction, id: direction)
  end

  private

  def promotion? = @base.klass == Promotion

  def search(scope)
    return scope if @filters[:search].blank?

    query = "%#{ApplicationRecord.sanitize_sql_like(@filters[:search].to_s.strip.first(150))}%"
    scope.where('name ILIKE :q OR code ILIKE :q', q: query)
  end

  def filter_validity(scope, validity)
    case validity
    when 'current' then scope.effective_at(@at)
    when 'upcoming' then scope.where('starts_at > ?', @at)
    when 'ended' then scope.where(ends_at: ..@at)
    else scope
    end
  end

  def filter_status(scope)
    status = @filters[:status]
    return scope.where(status:) if %w[draft paused archived].include?(status)

    case status
    when 'scheduled' then filter_validity(scope.where(status: 'active'), 'upcoming')
    when 'expired' then filter_validity(scope.where(status: 'active'), 'ended')
    when 'active', 'exhausted' then filter_current_status(scope, status)
    else scope
    end
  end

  def filter_current_status(scope, status)
    current = scope.where(status: 'active').effective_at(@at)
    return filter_usage(current, status == 'active' ? 'available' : 'exhausted') if promotion?

    status == 'active' ? current : scope.none
  end

  def filter_usage(scope, usage)
    case usage
    when 'exhausted' then scope.where("usage_limit <= #{USAGE_COUNT_SQL}")
    when 'available' then scope.where("usage_limit IS NULL OR usage_limit > #{USAGE_COUNT_SQL}")
    else scope
    end
  end

  def filter_lists(scope)
    scope = scope.where(customer_segment: @filters[:customer_segment]) if @filters[:customer_segment].present?
    return scope if @filters[:product_id].blank?

    items = PriceListItem.where(product_id: @filters[:product_id])
    scope.where(id: items.select(:price_list_id))
  end

  def filter_promotions(scope)
    scope = filter_usage(scope, @filters[:usage])
    if PromotionBenefit.kinds.key?(@filters[:benefit_kind])
      benefits = PromotionBenefit.where(kind: @filters[:benefit_kind])
      scope = scope.where(id: benefits.select(:promotion_id))
    end
    scope = filter_promotion_targets(scope)
    filter_promotion_segment(scope)
  end

  def filter_promotion_targets(scope)
    { product_id: 'product', category_id: 'category' }.each do |field, kind|
      next if @filters[field].blank?

      conditions = PromotionCondition.where(kind: [kind, "excluded_#{kind}"], field => @filters[field])
      scope = scope.where(id: conditions.select(:promotion_id))
    end
    scope
  end

  def filter_promotion_segment(scope)
    return scope if @filters[:customer_segment].blank?

    segment = "%#{ApplicationRecord.sanitize_sql_like(@filters[:customer_segment].to_s.strip.first(100))}%"
    conditions = PromotionCondition.where(kind: 'customer_segment').where('customer_segment ILIKE ?', segment)
    scope.where(id: conditions.select(:promotion_id))
  end
end
