# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier workspace access without organization membership', type: :request do
  before { sign_in create(:user, :english) }

  [
    [:admin_account_payables_path],
    [:admin_purchase_orders_path],
    [:admin_supplier_addresses_path, 1],
    [:admin_supplier_contacts_path, 1],
    [:admin_supplier_schedules_path, 1],
    [:edit_admin_supplier_schedule_exception_path, 1, 1],
    [:new_admin_supplier_event_path, 1],
    [:admin_supplier_supplier_products_path, 1],
    [:admin_supplier_product_comparison_path, 1, 1],
    [:address_map_admin_supplier_path, 1]
  ].each do |route, *ids|
    it "denies access to #{route} before looking up another organization's records" do
      get public_send(route, *ids)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
