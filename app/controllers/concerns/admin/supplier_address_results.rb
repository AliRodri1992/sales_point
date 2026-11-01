# frozen_string_literal: true

module Admin
  module SupplierAddressResults
    extend ActiveSupport::Concern

    private

    def build_address_page
      Suppliers::DossierAddressesPage.new(
        supplier: @supplier, status: params[:status], page: params[:page],
        query: params[:q], filter: params[:filter]
      ).call
    end

    def render_address_results
      set_address_page_headers
      render partial: 'address_cards', locals: address_result_locals
    end

    def set_address_page_headers
      response.headers['X-Next-Page'] = @address_page.next_page.to_s
      response.headers['X-Addresses-Count'] = @address_page.total_count.to_s
      response.headers['X-Addresses-Filter-Counts'] = @address_page.filter_counts.to_json
      response.headers['Cache-Control'] = 'private, no-store'
    end

    def address_result_locals
      { addresses: @address_page.addresses, can_manage_addresses: policy(@supplier).manage_addresses? }
    end
  end
end
