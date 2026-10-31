# frozen_string_literal: true

class SupplierBankAccountPolicy < FinancialPolicy
  def index?
    organization_access? && (allowed?('accounts_payable.banks.view') ||
                             %w[manage create update destroy restore review].any? { |action| allowed?("accounts_payable.banks.#{action}") })
  end

  def show? = index?
  def create? = banking_permission?('create')
  def edit? = update?
  def update? = banking_permission?('update')
  def destroy? = banking_permission?('destroy')
  def restore? = banking_permission?('restore')
  def review? = banking_permission?('review')
  def reveal? = organization_access? && allowed?('accounts_payable.banks.reveal')

  private

  def banking_permission?(action)
    organization_access? && (allowed?("accounts_payable.banks.#{action}") ||
                            allowed?('accounts_payable.banks.manage'))
  end

  public

  class Scope < FinancialPolicy::Scope
    def resolve
      return scope.none unless user && (user.admin? || user.permission?('accounts_payable.banks.view') ||
        %w[manage create update destroy restore review].any? { |action| user.permission?("accounts_payable.banks.#{action}") })

      ids = user.organization_memberships.where(status: :active).joins(:organization)
                .merge(Organization.active_records).select(:organization_id)
      scope.where(organization_id: ids)
    end
  end
end
