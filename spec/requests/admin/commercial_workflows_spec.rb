# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Independent commercial catalog workflows', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:offer) do
    organization.promotions.create!(name: 'Draft campaign', currency: 'MXN',
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
  end

  before do
    create(:organization_membership, user:, organization:)
    create(:currency, code: 'MXN')
    sign_in user
  end

  it 'generates draft list identity and ignores forged lifecycle and code attributes' do
    post admin_price_lists_path, params: { price_list: { name: 'Trade list', code: 'FORGED', status: 'active' } }
    expect(response).to have_http_status(:see_other)
    list = organization.price_lists.sole
    expect(list).to be_draft
    expect(list.code).to match(/\ALP-\d{6}\z/)
    original_code = list.code
    patch admin_price_list_path(list), params: { price_list: { name: 'Rename', code: 'OTHER', status: 'archived' } }
    expect(list.reload).to have_attributes(name: 'Rename', code: original_code, status: 'draft')
    events = FinancialAuditEvent.where(organization:, subject_type: 'PriceList', subject_id: list.id, actor: user)
    expect(events.order(:id).pluck(:event)).to eq(%w[price_list.create price_list.update])
  end

  it 'records campaign changes only when the whole write succeeds' do
    post admin_promotions_path, params: { promotion: { name: 'Campaign audit', currency: 'MXN' } }
    promotion = organization.promotions.sole
    events = FinancialAuditEvent.where(organization:, subject_type: 'Promotion', subject_id: promotion.id, actor: user)
    expect(events.pluck(:event)).to eq(['promotion.create'])
    patch admin_promotion_path(promotion), params: { promotion: { name: 'Campaign revised', usage_limit: 0 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(events.count).to eq(1)
    patch admin_promotion_path(promotion), params: { promotion: { name: 'Campaign revised' } }
    expect(events.order(:id).pluck(:event)).to eq(%w[promotion.create promotion.update])
  end

  it 'runs explicit lifecycle operations and prevents updates to archived data' do
    patch transition_admin_promotion_path(offer), params: { commercial_action: 'activate' }
    expect(offer.reload).to be_active
    patch transition_admin_promotion_path(offer), params: { commercial_action: 'pause' }
    expect(offer.reload).to be_paused
    patch transition_admin_promotion_path(offer), params: { commercial_action: 'resume' }
    expect(offer.reload).to be_active
    patch transition_admin_promotion_path(offer), params: { commercial_action: 'archive' }
    expect(offer.reload).to be_archived
    patch admin_promotion_path(offer), params: { promotion: { name: 'Forbidden' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(offer.reload.name).to eq('Draft campaign')
    patch transition_admin_promotion_path(offer), params: { commercial_action: 'duplicate' }
    copy = organization.promotions.where.not(id: offer.id).sole
    expect(response).to redirect_to(admin_promotion_path(copy))
    expect(copy).to be_draft
    expect(copy.code).not_to eq(offer.code)
  end

  it 'rejects unsupported lifecycle actions and foreign member IDs' do
    patch transition_admin_promotion_path(offer), params: { commercial_action: 'update' }
    expect(response).to have_http_status(:bad_request)
    foreign = Promotion.create!(organization: create(:organization), name: 'Foreign', currency: 'MXN')
    patch transition_admin_promotion_path(foreign), params: { commercial_action: 'archive' }
    expect(response).to have_http_status(:not_found)
    expect(foreign.reload).to be_draft
  end

  it 'scopes scanner lookups, selectable options and costs to the authorized context' do
    variant = product.product_variants.create!(name: 'Blue', sku: 'SCAN-ALPHA')
    product.product_variants.create!(name: 'Old', status: 'inactive')
    create(:product, organization: create(:organization), name: 'SCAN-ALPHA')
    get products_lookup_admin_price_lists_path, params: { q: 'SCAN-ALPHA' }
    expect(response.parsed_body.fetch('products').sole).to include('id' => product.id, 'currency' => 'MXN',
                                                                   'variants' => [{ 'id' => variant.id,
                                                                                    'name' => variant.name }])
    reader = create(:user, :english)
    create(:organization_membership, user: reader, organization:)
    role = create(:system_role, :system)
    create(:user_role, user: reader, system_role: role)
    GranularPermissionCatalog.sync!
    %w[price_lists.access price_lists.index].each do |code|
      create(:system_role_permission, system_role: role, permission: Permission.find_by!(code:))
    end
    sign_in reader
    get products_lookup_admin_price_lists_path, params: { q: variant.sku }
    expect(response.parsed_body.fetch('products').sole).not_to have_key('cost')
    get products_lookup_admin_promotions_path, params: { q: variant.sku }
    expect(response).to have_http_status(:forbidden)
    list = organization.price_lists.create!(name: 'Private list', currency: 'MXN')
    patch transition_admin_price_list_path(list), params: { commercial_action: 'archive' }
    expect(response).to have_http_status(:forbidden)
    expect(list.reload).to be_draft
  end

  it 'omits foreign categories from searches and validation responses' do
    local = create(:category, organization:, name: 'Shared prefix local')
    create(:category, organization:, name: 'Shared prefix old', status: 'inactive')
    foreign = create(:category, organization: create(:organization), name: 'Shared prefix private')
    get categories_lookup_admin_promotions_path, params: { q: 'Shared prefix' }
    expect(response.parsed_body.fetch('categories').sole.fetch('id')).to eq(local.id)
    patch admin_promotion_path(offer), params: { promotion: {
      promotion_conditions_attributes: { '0' => { kind: 'category', category_id: foreign.id } }
    } }
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(foreign.name)
    expect(offer.reload.promotion_conditions).to be_empty
  end

  it 'preserves campaign fields and active selections when validation fails' do
    post admin_promotions_path, params: { promotion: {
      name: 'Retained campaign', usage_limit: 0, currency: 'MXN',
      promotion_conditions_attributes: { '0' => { kind: 'product', product_id: product.id } }
    } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Retained campaign', product.name)
    expect(organization.promotions).to be_empty
  end

  it 'previews one draft campaign without creating a redemption and rejects foreign options' do
    expect do
      get preview_admin_promotion_path(offer), params: { product_id: product.id, quantity: 2 }
    end.not_to change(PromotionRedemption, :count)
    expect(response.parsed_body).to include('currency' => 'MXN', 'promotion' => offer.name)
    expect(response.parsed_body.fetch('total').to_d).to eq(180)
    get preview_admin_promotion_path(offer), params: { product_id: product.id, quantity: { units: 2 } }
    expect(response).to have_http_status(:unprocessable_content)
    foreign = create(:product).product_variants.create!(name: 'Other')
    get preview_admin_promotion_path(offer), params: { product_id: product.id, variant_id: foreign.id }
    expect(response).to have_http_status(:not_found)
  end

  it 'combines effective status, validity, audience, benefit and usage filters before pagination' do
    category = create(:category, organization:)
    offer.update!(status: 'active', starts_at: 1.day.from_now, usage_limit: 2,
                  promotion_conditions_attributes: [{ kind: 'customer_segment', customer_segment: 'Trade' },
                                                    { kind: 'product', product: }, { kind: 'category', category: }])
    organization.promotions.create!(name: 'Different campaign', currency: 'MXN')
    get admin_promotions_path, params: { status: 'scheduled', validity: 'upcoming', benefit_kind: 'percentage',
                                         usage: 'available', product_id: product.id, category_id: category.id,
                                         currency: 'MXN', customer_segment: 'Trade', page: 100 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(offer.name)
    expect(response.body).not_to include('Different campaign')
    get admin_promotions_path, params: { usage: 'exhausted' }
    expect(response.body).not_to include(offer.name)
  end

  it 'evaluates global usage and expiration in the same order as a displayed campaign' do
    offer.update!(status: 'active', usage_limit: 1)
    offer.promotion_redemptions.create!(organization:, product:, quantity: 1, discount: 10, idempotency_key: 'last-use')
    get admin_promotions_path, params: { status: 'exhausted', usage: 'exhausted' }
    expect(response.body).to include(offer.name)
    offer.update!(ends_at: 1.hour.ago)
    get admin_promotions_path, params: { status: 'exhausted' }
    expect(response.body).not_to include(offer.name)
    get admin_promotions_path, params: { status: 'expired', usage: 'exhausted' }
    expect(response.body).to include(offer.name)
  end
end
