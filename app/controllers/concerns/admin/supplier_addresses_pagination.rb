# frozen_string_literal: true

module Admin
  module SupplierAddressesPagination
    private

    def render_dossier_addresses_page
      authorize @supplier, :show?
      authorize @supplier, :view_addresses?
      page = paginated_supplier_addresses
      apply_addresses_page_headers(page)
      render_addresses_page(page)
    end

    def paginated_supplier_addresses
      Suppliers::DossierAddressesPage.new(
        supplier: @supplier,
        page: params[:page],
        query: params[:q],
        filter: params[:filter]
      ).call
    end

    def apply_addresses_page_headers(page)
      response.headers['X-Next-Page'] = page.next_page.to_s
      response.headers['X-Addresses-Count'] = page.total_count.to_s
      response.headers['X-Addresses-Filter-Counts'] = page.filter_counts.to_json
      response.headers['Cache-Control'] = 'private, no-store'
    end

    def render_addresses_page(page)
      render partial: 'admin/suppliers/dossier_address_cards',
             locals: {
               addresses: page.addresses,
               supplier: @supplier,
               can_manage_addresses: policy(@supplier).manage_addresses?
             }
    end
  end
end
