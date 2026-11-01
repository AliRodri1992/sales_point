# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organization-owned product isolation', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  before do
    create(:organization_membership, organization:, user:)
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

  it 'assigns the active organization to newly created products' do
    attributes = attributes_for(:product)
    post admin_products_path, params: { product: attributes }

    expect(Product.order(:id).last.organization).to eq(organization)
  end
end
