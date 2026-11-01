# frozen_string_literal: true

class PurchaseOrderPolicy < ApplicationPolicy
  def index? = organization_access? && permitted?('purchases.view')
  def show? = index?
  def create? = organization_access? && permitted?('purchases.create')
  def new? = create?
  def edit? = create? && record.draft?
  def update? = edit?
  def submit? = create?
  def approve? = organization_access? && permitted?('purchases.approve')
  def reject? = approve?
  def dispatch? = approve?
  def cancel? = approve?
  def close? = approve?
  def receive? = organization_access? && permitted?('purchases.receive')
  def return? = organization_access? && permitted?('purchases.returns')

  private

  def organization_access?
    return false unless user && record.organization_id

    user.organization_memberships.where(organization_id: record.organization_id, status: :active)
        .joins(:organization).merge(Organization.active_records).exists?
  end

  def permitted?(key)
    user.admin? || user.permission?(key)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user && (user.admin? || user.permission?('purchases.view'))

      ids = user.organization_memberships.where(status: :active).joins(:organization)
                .merge(Organization.active_records).select(:organization_id)
      scope.where(organization_id: ids)
    end
  end
end
