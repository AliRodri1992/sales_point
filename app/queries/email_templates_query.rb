# frozen_string_literal: true

class EmailTemplatesQuery
  attr_reader :date_errors

  def initialize(scope, filters = {}, include_archived: false, **filter_keywords)
    @scope = scope
    @filters = filters.merge(filter_keywords)
    @include_archived = include_archived
    @date_errors = {}
  end

  def call
    scope = search(@scope)
    scope = filter_locale(scope)
    scope = filter_status(scope)
    scope = filter_category(scope)
    scope = filter_scope(scope)
    scope = filter_origin(scope)
    filter_updated_at(scope)
  end

  private

  def search(scope)
    return scope if @filters[:q].blank?

    escaped = ActiveRecord::Base.sanitize_sql_like(@filters[:q].to_s.strip.first(150))
    scope.where('email_templates.key ILIKE :q OR email_templates.name ILIKE :q ' \
                'OR email_templates.subject ILIKE :q', q: "%#{escaped}%")
  end

  def filter_locale(scope)
    return scope unless @filters[:locale].in?(%w[es en ko])

    scope.where(locale: @filters[:locale])
  end

  def filter_status(scope)
    return scope.where(status: @filters[:status]) if @filters[:status].in?(EmailTemplate::STATUSES)
    return scope if @include_archived

    scope.where.not(status: 'archived')
  end

  def filter_category(scope)
    return scope if @filters[:category].blank?

    scope.where(category: @filters[:category])
  end

  def filter_scope(scope)
    case @filters[:scope]
    when 'global' then scope.where(organization_id: nil)
    when 'organization' then scope.where.not(organization_id: nil)
    else scope
    end
  end

  def filter_origin(scope)
    case @filters[:origin]
    when 'system' then scope.where(organization_id: nil)
    when 'customized' then scope.where.not(source_template_id: nil)
    when 'organization' then scope.where.not(organization_id: nil).where(source_template_id: nil)
    else scope
    end
  end

  def filter_updated_at(scope)
    from = parsed_date(:updated_from)
    to = parsed_date(:updated_to)
    @date_errors[:updated_to] = :before_start if from && to && from > to
    return scope if @date_errors.any?

    scope = scope.where(updated_at: from.beginning_of_day..) if from
    scope = scope.where(updated_at: ..to.end_of_day) if to
    scope
  end

  def parsed_date(key)
    value = @filters[key].to_s
    return if value.blank?

    unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      @date_errors[key] = :invalid
      return
    end

    Date.iso8601(value)
  rescue ArgumentError
    @date_errors[key] = :invalid
    nil
  end
end
