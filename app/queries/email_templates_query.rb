# frozen_string_literal: true

class EmailTemplatesQuery
  def initialize(scope, filters)
    @scope = scope
    @filters = filters
  end

  def call
    scope = @scope
    if @filters[:q].present?
      escaped = ActiveRecord::Base.sanitize_sql_like(@filters[:q])
      scope = scope.where('key ILIKE :q OR name ILIKE :q', q: "%#{escaped}%")
    end
    scope = scope.where(locale: @filters[:locale]) if @filters[:locale].in?(%w[es en ko])
    scope = scope.where(status: @filters[:status]) if @filters[:status].in?(EmailTemplate::STATUSES)
    scope
  end
end
