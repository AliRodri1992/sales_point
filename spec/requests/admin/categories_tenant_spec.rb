# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Categories organization isolation', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:administrator) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, organization:, user: administrator)
    sign_in administrator
  end

  it 'hides foreign categories on index and prevents show, update and delete' do
    own = create(:category, organization:, name: 'My only category')
    foreign = create(:category, organization: other_organization, name: 'Foreign private category')

    get admin_categories_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own.name)
    expect(response.body).not_to include(foreign.name)

    get admin_category_path(foreign)
    expect(response).to have_http_status(:not_found)
    patch admin_category_path(foreign), params: { category: { name: 'Forged edit' } }
    expect(response).to have_http_status(:not_found)
    delete admin_category_path(foreign)
    expect(response).to have_http_status(:not_found)
    expect(foreign.reload.deleted_at).to be_nil
  end

  it 'allows separate organizations to use the same category code' do
    create(:category, organization: other_organization, code: 'grocery', name: 'Other groceries')
    post admin_categories_path, params: { category: { name: 'My groceries', code: 'grocery' } }

    expect(response).to have_http_status(:redirect)
    expect(Category.find_by!(organization:, code: 'grocery').name).to eq('My groceries')
  end

  it 'rejects cross-organization category assignment to a product' do
    foreign = create(:category, organization: other_organization)
    product = create(:product, organization:)
    product.category = foreign
    expect(product).not_to be_valid
    expect(product.errors[:category_id]).to be_present
  end

  it 'rejects cross-organization category references on promotion conditions' do
    foreign = create(:category, organization: other_organization)
    promotion = Promotion.new(organization:, name: 'Tenant promo', code: 'TENANT-PROMO', currency: 'MXN')
    condition = promotion.promotion_conditions.build(kind: 'category', category: foreign)
    expect(condition).not_to be_valid
    expect(condition.errors[:category]).to be_present
  end
end
