# frozen_string_literal: true

class SupplierPolicy
  DOSSIER_PERMISSIONS = %w[
    suppliers.view suppliers.update suppliers.contacts.view suppliers.contacts.manage
    suppliers.addresses.view suppliers.addresses.manage suppliers.schedules.view
    suppliers.schedules.manage suppliers.documents.view suppliers.documents.manage
    suppliers.fiscal.view suppliers.fiscal.manage suppliers.commercial.view
    suppliers.commercial.manage suppliers.products.view suppliers.products.manage
    accounts_payable.view accounts_payable.banks.view accounts_payable.banks.manage
  ].freeze

  attr_reader :user, :supplier

  def initialize(user, supplier)
    @user = user
    @supplier = supplier
  end

  def index?
    authorized_organization? && DOSSIER_PERMISSIONS.any? { |permission| allowed?(permission) }
  end

  def show? = authorized_record? && DOSSIER_PERMISSIONS.any? { |permission| allowed?(permission) }
  def new? = authorized_organization? && allowed?('suppliers.create')
  def create? = new?
  def edit? = authorized_record? && allowed?('suppliers.update')
  def update? = edit?
  def destroy? = authorized_record? && allowed?('suppliers.destroy')
  def restore? = destroy?
  def view_general? = authorized_record? && (allowed?('suppliers.view') || allowed?('suppliers.update'))

  def view_contacts?
    authorized_record? && (allowed?('suppliers.contacts.view') || allowed?('suppliers.contacts.manage'))
  end

  def manage_contacts? = authorized_record? && allowed?('suppliers.contacts.manage')

  def view_addresses?
    authorized_record? && (allowed?('suppliers.addresses.view') || allowed?('suppliers.addresses.manage'))
  end

  def manage_addresses? = authorized_record? && allowed?('suppliers.addresses.manage')

  def view_schedules?
    authorized_record? && (allowed?('suppliers.schedules.view') || allowed?('suppliers.schedules.manage'))
  end

  def manage_schedules? = authorized_record? && allowed?('suppliers.schedules.manage')

  def view_documents?
    authorized_record? && (allowed?('suppliers.documents.view') || allowed?('suppliers.documents.manage'))
  end

  def manage_documents? = authorized_record? && allowed?('suppliers.documents.manage')

  def view_fiscal?
    authorized_record? && (allowed?('suppliers.fiscal.view') || allowed?('suppliers.fiscal.manage'))
  end

  def manage_fiscal? = authorized_record? && allowed?('suppliers.fiscal.manage')

  def view_commercial?
    authorized_record? && (allowed?('suppliers.commercial.view') || allowed?('suppliers.commercial.manage'))
  end

  def manage_commercial? = authorized_record? && allowed?('suppliers.commercial.manage')

  def view_products?
    authorized_record? && (allowed?('suppliers.products.view') || allowed?('suppliers.products.manage'))
  end

  def manage_products? = authorized_record? && allowed?('suppliers.products.manage')
  def export? = authorized_organization? && allowed?('suppliers.export')

  private

  def allowed?(permission)
    user.admin? || user.permission?(permission)
  end

  def authorized_organization?
    return false unless user

    active_memberships.exists?
  end

  def authorized_record?
    return false unless user

    authorized_organization? && supplier.respond_to?(:organization_id) &&
      supplier.organization_id.present? &&
      active_memberships.exists?(organization_id: supplier.organization_id)
  end

  def active_memberships
    user.organization_memberships.where(status: :active)
        .joins(:organization).merge(Organization.active_records)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return @scope.none unless @user && (@user.admin? ||
        DOSSIER_PERMISSIONS.any? { |permission| @user.permission?(permission) })

      memberships = @user.organization_memberships.where(status: :active)
                         .joins(:organization).merge(Organization.active_records)
      @scope.where(organization_id: memberships.select(:organization_id))
    end
  end
end
