# frozen_string_literal: true

class SupplierBankAccountPolicy < FinancialPolicy
  def index?
    organization_access? && (allowed?('accounts_payable.banks.view') ||
                             allowed?('accounts_payable.banks.manage'))
  end

  def show? = index?
  def create? = organization_access? && allowed?('accounts_payable.banks.manage')
  def edit? = create?
  def update? = create?
  def destroy? = create?
  def reveal? = organization_access? && allowed?('accounts_payable.banks.reveal')

  class Scope < FinancialPolicy::Scope
    def resolve
      return scope.none unless user && (user.admin? || user.permission?('accounts_payable.banks.view') ||
        user.permission?('accounts_payable.banks.manage'))

      ids = user.organization_memberships.where(status: :active).joins(:organization)
                .merge(Organization.active_records).select(:organization_id)
      scope.where(organization_id: ids)
    end
  end
end
