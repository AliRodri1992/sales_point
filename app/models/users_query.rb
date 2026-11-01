# frozen_string_literal: true

# Filters a User relation by the advanced search params of the admin users
# index (search box, type, status and role). Kept out of the controller so the
# action respects the project's Metrics/Clean Architecture thresholds.
class UsersQuery
  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  def call
    by_role(by_status(by_user_type(by_search(@scope))))
  end

  private

  def by_search(scope)
    q = @params[:q].to_s.strip
    return scope if q.blank?

    scope.where('users.email ILIKE :q OR users.username ILIKE :q', q: "%#{q}%")
  end

  def by_user_type(scope)
    return scope unless User.user_types.key?(@params[:user_type])

    scope.where(user_type: @params[:user_type])
  end

  def by_status(scope)
    return scope unless User.statuses.key?(@params[:status])

    scope.where(status: @params[:status])
  end

  def by_role(scope)
    return scope if @params[:role].blank?

    scope.joins(:system_roles).where(system_roles: { id: @params[:role] }).distinct
  end
end
