# frozen_string_literal: true

# Loads each permitted dossier section while keeping the supplier controller small.
module SupplierDossierLoading
  private

  def load_dossier_sections
    supplier_policy = policy(@supplier)
    load_dossier_contacts if supplier_policy.view_contacts?
    load_dossier_addresses if supplier_policy.view_addresses?
    load_dossier_documents if supplier_policy.view_documents?
    load_dossier_products if supplier_policy.view_products?
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
