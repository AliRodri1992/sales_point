# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin supplier procurement', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:product) { create(:product, organization:) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def valid_offer
    {
      product_id: product.id, currency_id: supplier.currency.id,
      presentation_name: 'Case', units_per_package: 12, purchase_price: 120,
      minimum_quantity: 1, discount_percent: 0, freight_amount: 0,
      nonrecoverable_tax: 0, lead_time_days: 3
    }
  end

  it 'creates a product offer scoped to the current organization' do
    post admin_supplier_supplier_products_path(supplier), params: { supplier_product: valid_offer }

    expect(response).to redirect_to(admin_supplier_supplier_products_path(supplier))
    expect(SupplierProduct.last).to have_attributes(organization_id: organization.id, product_id: product.id)
  end

  it 'rejects products owned by another organization' do
    foreign_product = create(:product, organization: create(:organization))
    post admin_supplier_supplier_products_path(supplier),
         params: { supplier_product: valid_offer.merge(product_id: foreign_product.id) }

    expect(response).to have_http_status(:not_found)
    expect(SupplierProduct.count).to eq(0)
  end

  it 'rejects foreign supplier access' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    get admin_supplier_supplier_products_path(foreign_supplier)

    expect(response).to have_http_status(:not_found)
  end

  it 'shows the cost comparison for products in this organization' do
    SupplierProduct.create!(valid_offer.except(:product_id, :currency_id).merge(
                              organization:, supplier:, product:, currency: supplier.currency
                            ))
    get admin_supplier_product_comparison_path(supplier, product_id: product.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(product.name)
  end
end
