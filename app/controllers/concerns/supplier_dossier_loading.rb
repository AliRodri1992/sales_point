# frozen_string_literal: true

# Loads each permitted dossier section while keeping the supplier controller small.
module SupplierDossierLoading
  private

  def load_dossier_sections
    supplier_policy = policy(@supplier)
    if supplier_policy.view_contacts?
      @dossier_contacts_page = Suppliers::DossierContactsPage.new(supplier: @supplier).call
    end
    if supplier_policy.view_addresses?
      @dossier_addresses_page = Suppliers::DossierAddressesPage.new(supplier: @supplier).call
    end
    if supplier_policy.view_documents?
      SupplierDocument.import_existing!(@supplier)
      @dossier_documents_page = Suppliers::DossierDocumentsPage.new(
        supplier: @supplier, page: params[:documents_page], query: params[:documents_q],
        category: params[:documents_category], status: params[:documents_status], days: params[:documents_days]
      ).call
    end
    return unless supplier_policy.view_products?

    @dossier_products_page = Suppliers::DossierProductsPage.new(
      supplier: @supplier, page: params[:products_page]
    ).call
  end
end
