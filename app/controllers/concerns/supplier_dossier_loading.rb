# frozen_string_literal: true

# Loads each permitted dossier section while keeping the supplier controller small.
module SupplierDossierLoading
  private

  def load_dossier_sections
    supplier_policy = policy(@supplier)
    load_dossier_contacts if supplier_policy.view_contacts?
    load_dossier_addresses if supplier_policy.view_addresses?
    load_dossier_documents if supplier_policy.view_documents?
    load_dossier_calendar if supplier_policy.view_schedules?
    load_dossier_products if supplier_policy.view_products?
  end

  def load_dossier_calendar
    @supplier_calendar = Suppliers::CalendarBoard.new(supplier: @supplier, **calendar_options)
    @calendar_archived_events = archived_calendar_events
    @calendar_branches = current_organization.branches.not_deleted.order(:name)
  end

  def calendar_options
    { month: params[:calendar_month], day: params[:calendar_day], view: params[:calendar_view],
      branch_id: params[:calendar_branch], kind: params[:calendar_kind],
      selected_day: params[:calendar_selected_day] }
  end

  def archived_calendar_events
    return [] unless policy(@supplier).manage_schedules?

    @supplier.supplier_events.with_deleted.where.not(deleted_at: nil).includes(:branch)
             .order(deleted_at: :desc).limit(8)
  end

  def load_dossier_contacts
    @dossier_contacts_page = Suppliers::DossierContactsPage.new(supplier: @supplier).call
  end

  def load_dossier_addresses
    @dossier_addresses_page = Suppliers::DossierAddressesPage.new(supplier: @supplier).call
  end

  def load_dossier_documents
    @dossier_documents_page = Suppliers::DossierDocumentsPage.new(
      supplier: @supplier, page: params[:documents_page],
      filters: {
        query: params[:documents_q], category: params[:documents_category],
        status: params[:documents_status], days: params[:documents_days]
      }
    ).call
  end

  def load_dossier_products
    @dossier_products_page = Suppliers::DossierProductsPage.new(
      supplier: @supplier, page: params[:products_page]
    ).call
  end
end
