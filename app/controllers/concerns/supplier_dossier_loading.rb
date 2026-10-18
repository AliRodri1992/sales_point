# frozen_string_literal: true

# Loads each permitted dossier section while keeping the supplier controller small.
module SupplierDossierLoading
  private

  def load_dossier_sections
    @dossier_contacts_page = Suppliers::DossierContactsPage.new(supplier: @supplier).call
    @dossier_addresses_page = Suppliers::DossierAddressesPage.new(supplier: @supplier).call
    return unless policy(@supplier).view_products?

    @dossier_products_page = Suppliers::DossierProductsPage.new(
      supplier: @supplier, page: params[:products_page]
    ).call
  end
end
