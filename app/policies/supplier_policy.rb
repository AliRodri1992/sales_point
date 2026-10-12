# frozen_string_literal: true

class SupplierPolicy
  attr_reader :user, :supplier

  def initialize(user, supplier)
    @user = user
    @supplier = supplier
  end

  def index? = authorized_organization? && allowed?('suppliers.view')
  def show? = authorized_record? && allowed?('suppliers.view') && full_dossier_access?
  def new? = authorized_organization? && allowed?('suppliers.create')
  def create? = new?
  def edit? = authorized_record? && allowed?('suppliers.update')
  def update? = edit?
  def destroy? = authorized_record? && allowed?('suppliers.destroy')

  def view_contacts? = authorized_record? && allowed?('suppliers.contacts.view')
  def manage_contacts? = authorized_record? && allowed?('suppliers.contacts.manage')
  def view_addresses? = authorized_record? && allowed?('suppliers.addresses.view')
  def manage_addresses? = authorized_record? && allowed?('suppliers.addresses.manage')
  def view_schedules? = authorized_record? && allowed?('suppliers.schedules.view')
  def manage_schedules? = authorized_record? && allowed?('suppliers.schedules.manage')
  def view_documents? = authorized_record? && allowed?('suppliers.documents.view')
  def manage_documents? = authorized_record? && allowed?('suppliers.documents.manage')
  def view_fiscal? = authorized_record? && allowed?('suppliers.fiscal.view')
  def manage_fiscal? = authorized_record? && allowed?('suppliers.fiscal.manage')
  def view_commercial? = authorized_record? && allowed?('suppliers.commercial.view')
  def manage_commercial? = authorized_record? && allowed?('suppliers.commercial.manage')
  def export? = authorized_organization? && allowed?('suppliers.export')

  private

  def full_dossier_access?
    user.admin? || %w[
      suppliers.contacts.view suppliers.addresses.view suppliers.schedules.view
      suppliers.documents.view suppliers.fiscal.view suppliers.commercial.view
    ].all? { |permission| user.permission?(permission) }
  end

  def allowed?(permission)
    user.admin? || user.permission?(permission)
  end

  def authorized_organization?
    return unless user

    user.organizations.active_records.exists?
  end

  def authorized_record?
    return unless user

    authorized_organization? && supplier.respond_to?(:organization_id) &&
      supplier.organization_id.present? &&
      user.organizations.active_records.exists?(id: supplier.organization_id)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return @scope.none unless @user && (@user.admin? || @user.permission?('suppliers.view'))

      @scope.where(organization_id: @user.organizations.active_records.select(:id))
    end
  end
end
