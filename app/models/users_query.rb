# frozen_string_literal: true

# Filters a User relation by the advanced search params of the admin users
# index (search box, type, status and role). Kept out of the controller so the
# action respects the project's Metrics/Clean Architecture thresholds.
class UsersQuery
  def initialize(scope, params, organization: nil)
    @scope = scope
    @params = params
    @organization = organization
  end

  def call
    by_branch(by_role(by_status(by_user_type(by_search(@scope)))))
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

    return scope.where(status: @params[:status]) unless @organization

    memberships = OrganizationMembership.active.where(
      organization: @organization, account_status: @params[:status], deleted_at: nil
    ).select(:user_id)
    scope.where(id: memberships)
  end

  def by_role(scope)
    return scope if @params[:role].blank?

    assignments = UserRole.active.where(system_role_id: @params[:role])
    if @organization
      branch_ids = @organization.branches.not_deleted.where(operational_status: 'active').select(:id)
      assignments = assignments.where(branch_id: nil).or(assignments.where(branch_id: branch_ids))
    end
    scope.where(id: assignments.select(:user_id))
  end

  def by_branch(scope)
    return scope if @params[:branch].blank? || @organization.nil?

    branches = @organization.branches.not_deleted.where(operational_status: 'active')
    return scope.none unless branches.exists?(id: @params[:branch])

    assignments = UserRole.active.where(branch_id: @params[:branch])
    if @params[:role].present? && SystemRole.branch.exists?(id: @params[:role])
      assignments = assignments.where(system_role_id: @params[:role])
    end
    scope.where(id: assignments.select(:user_id))
  end
end
