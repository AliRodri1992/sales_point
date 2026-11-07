# frozen_string_literal: true

class EmailTemplatesQuery
  def initialize(scope, filters)
    @scope = scope
    @filters = filters
  end

  def call
    scope = search(@scope)
    scope = scope.where(locale: @filters[:locale]) if @filters[:locale].in?(%w[es en ko])
    scope = if @filters[:status].in?(EmailTemplate::STATUSES)
              scope.where(status: @filters[:status])
            else
              scope.where.not(status: 'archived')
            end
    scope = scope.where(category: @filters[:category]) if @filters[:category].present?
    scope = filter_scope(scope)
    from = parsed_date(:updated_from)
    to = parsed_date(:updated_to)
    scope = scope.where(updated_at: from.beginning_of_day..) if from
    scope = scope.where(updated_at: ..to.end_of_day) if to
    scope
  end

  private

  def search(scope)
    return scope if @filters[:q].blank?

    escaped = ActiveRecord::Base.sanitize_sql_like(@filters[:q].to_s.strip.first(150))
    scope.where('email_templates.key ILIKE :q OR email_templates.name ILIKE :q ' \
                'OR email_templates.subject ILIKE :q', q: "%#{escaped}%")
  end

  def filter_scope(scope)
    case @filters[:scope]
    when 'global' then scope.where(organization_id: nil)
    when 'organization' then scope.where.not(organization_id: nil)
    else scope
    end
  end

  def parsed_date(key)
    value = @filters[key].to_s
    return unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end
end
