# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization-owned product isolation', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, organization:, user:)
    permission_role = create(:system_role, :system)
    create(:user_role, user:, system_role: permission_role)
    GranularPermissionCatalog.sync!
    codes = GranularPermissionCatalog::ACTIONS.map { |action| "products.#{action}" }
    Permission.where(code: codes).find_each do |permission|
      create(:system_role_permission, system_role: permission_role, permission:)
    end
    sign_in user
  end

  it 'does not display products owned by another organization' do
    foreign = create(:product, organization: create(:organization), name: 'Other company only')
    get admin_products_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(foreign.name)
  end

  it 'does not open products owned by another organization' do
    foreign = create(:product, organization: create(:organization))
    get admin_product_path(foreign)

    expect(response).to redirect_to(admin_products_path)
  end

  it 'rejects a foreign organization category even if the form is forged' do
    foreign_category = create(:category, organization: create(:organization))
    params = attributes_for(:product).merge(category_id: foreign_category.id)

    expect do
      post admin_products_path, params: { product: params }
    end.not_to change(Product, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'returns a JSON error rather than redirecting for foreign quote options' do
    product = create(:product, organization:)
    foreign = create(:product, organization: create(:organization))
    variant = foreign.product_variants.create!(name: 'Foreign variant')

    get quote_admin_product_path(product), params: { variant_id: variant.id },
                                           headers: { 'ACCEPT' => 'application/json' }

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq('application/json')
    expect(response.parsed_body['error']).to be_present
  end

  it 'assigns the active organization to newly created products' do
    attributes = attributes_for(:product)
    post admin_products_path, params: { product: attributes }

    expect(Product.order(:id).last.organization).to eq(organization)
  end
end
