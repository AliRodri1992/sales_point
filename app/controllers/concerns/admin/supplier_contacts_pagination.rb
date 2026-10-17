# frozen_string_literal: true

module Admin
  module SupplierContactsPagination
    private

    def render_dossier_contacts_page
      authorize @supplier, :show?
      authorize @supplier, :view_contacts?
      page = paginated_supplier_contacts
      apply_contacts_page_headers(page)
      render_contacts_page(page)
    end

    def paginated_supplier_contacts
      Suppliers::DossierContactsPage.new(
        supplier: @supplier,
        page: params[:page],
        query: params[:q],
        filter: params[:filter]
      ).call
    end

    def apply_contacts_page_headers(page)
      response.headers['X-Next-Page'] = page.next_page.to_s
      response.headers['X-Contacts-Count'] = page.total_count.to_s
      response.headers['X-Contacts-Filter-Counts'] = page.filter_counts.to_json
      response.headers['Cache-Control'] = 'private, no-store'
    end

    def render_contacts_page(page)
      render partial: 'admin/suppliers/dossier_contact_cards',
             locals: {
               contacts: page.contacts,
               supplier: @supplier,
               can_manage_contacts: policy(@supplier).manage_contacts?
             }
    end
  end
end
