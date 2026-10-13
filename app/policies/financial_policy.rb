# frozen_string_literal: true

class FinancialPolicy < ApplicationPolicy
  def index? = organization_access? && allowed?('accounts_payable.view')
  def show? = index?
  def new? = create?
  def create? = organization_access? && allowed?('accounts_payable.manage')
  def edit? = create? && record.draft?
  def update? = edit?
  def post? = organization_access? && allowed?('accounts_payable.approve')
  def cancel? = post?
  def apply? = organization_access? && allowed?('accounts_payable.pay')
  def reverse? = organization_access? && allowed?('accounts_payable.pay')

  private

  def organization_access?
    return false unless user && record.organization_id

    user.organization_memberships.where(organization_id: record.organization_id, status: :active)
        .joins(:organization).merge(Organization.active_records).exists?
  end

  def allowed?(permission)
    user.admin? || user.permission?(permission)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user && (user.admin? || user.permission?('accounts_payable.view'))

      ids = user.organization_memberships.where(status: :active).joins(:organization)
                .merge(Organization.active_records).select(:organization_id)
      scope.where(organization_id: ids)
    end
  end
end

