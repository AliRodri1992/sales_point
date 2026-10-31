# frozen_string_literal: true

class SupplierPolicy
  DOSSIER_PERMISSIONS = %w[
    suppliers.view suppliers.update suppliers.contacts.view suppliers.contacts.manage
    suppliers.addresses.view suppliers.addresses.manage suppliers.schedules.view
    suppliers.schedules.manage suppliers.documents.view suppliers.documents.manage
    suppliers.fiscal.view suppliers.fiscal.manage suppliers.commercial.view
    suppliers.commercial.manage suppliers.products.view suppliers.products.manage
    accounts_payable.view accounts_payable.banks.view accounts_payable.banks.manage
    accounts_payable.banks.create accounts_payable.banks.update accounts_payable.banks.destroy
    accounts_payable.banks.restore accounts_payable.banks.review
    suppliers.export suppliers.create
    suppliers.contacts.create suppliers.contacts.update suppliers.contacts.destroy suppliers.contacts.restore
    suppliers.addresses.create suppliers.addresses.update suppliers.addresses.destroy suppliers.addresses.restore
    suppliers.addresses.set_primary suppliers.addresses.geocode
    suppliers.schedules.create suppliers.schedules.update suppliers.schedules.destroy suppliers.schedules.restore
  ].freeze

  # List access does not grant access to sensitive dossier sections.
  LIST_PERMISSIONS = (DOSSIER_PERMISSIONS + %w[suppliers.access suppliers.destroy]).freeze

  attr_reader :user, :supplier

  def initialize(user, supplier)
    @user = user
    @supplier = supplier
  end

  def index?
    authorized_organization? && LIST_PERMISSIONS.any? { |permission| allowed?(permission) }
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
    authorized_record? && (allowed?('suppliers.contacts.view') || contacts_any_action?)
  end

  def manage_contacts? = authorized_record? && allowed?('suppliers.contacts.manage')

  def view_addresses?
    authorized_record? && (allowed?('suppliers.addresses.view') || addresses_any_action?)
  end

  def manage_addresses? = authorized_record? && allowed?('suppliers.addresses.manage')

  def view_schedules?
    authorized_record? && (allowed?('suppliers.schedules.view') || schedules_any_action?)
  end

  def manage_schedules? = authorized_record? && allowed?('suppliers.schedules.manage')

  # Independent permissions supplement the legacy *.manage grants.
  # Existing roles remain operational while administrators can assign only
  # the individual CRUD actions needed for a workflow.
  def create_contacts? = section_action?('contacts', 'create')
  def update_contacts? = section_action?('contacts', 'update')
  def destroy_contacts? = section_action?('contacts', 'destroy')
  def restore_contacts? = section_action?('contacts', 'restore')

  def create_addresses? = section_action?('addresses', 'create')
  def update_addresses? = section_action?('addresses', 'update')
  def destroy_addresses? = section_action?('addresses', 'destroy')
  def restore_addresses? = section_action?('addresses', 'restore')
  def set_primary_address? = section_action?('addresses', 'set_primary')
  def geocode_address? = section_action?('addresses', 'geocode')

  def create_schedules? = section_action?('schedules', 'create')
  def update_schedules? = section_action?('schedules', 'update')
  def destroy_schedules? = section_action?('schedules', 'destroy')
  def restore_schedules? = section_action?('schedules', 'restore')

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

  def section_action?(section, action)
    authorized_record? && (allowed?("suppliers.#{section}.#{action}") ||
                           allowed?("suppliers.#{section}.manage"))
  end

  def contacts_any_action? = section_any_action?('contacts', %w[create update destroy restore])
  def addresses_any_action? = section_any_action?('addresses', %w[create update destroy restore set_primary geocode])
  def schedules_any_action? = section_any_action?('schedules', %w[create update destroy restore])

  def section_any_action?(section, actions)
    allowed?("suppliers.#{section}.manage") ||
      actions.any? { |action| allowed?("suppliers.#{section}.#{action}") }
  end

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
        LIST_PERMISSIONS.any? { |permission| @user.permission?(permission) })

      memberships = @user.organization_memberships.where(status: :active)
                         .joins(:organization).merge(Organization.active_records)
      @scope.where(organization_id: memberships.select(:organization_id))
    end
  end
end
