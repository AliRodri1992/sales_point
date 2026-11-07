# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial request security', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }
  let(:product) { create(:product, organization:, price: 100) }
  let(:event) do
    product.price_change_events.create!(organization:, actor: administrator, previous_price: 100,
                                        new_price: 120, currency: 'MXN', reason: 'Supplier review')
  end

  before do
    create(:organization_membership, user: administrator, organization:)
    create(:user_role, user: administrator, system_role: create(:system_role, :system, code: 'administrator'))
    create(:currency, code: 'MXN')
    sign_in administrator
  end

  it 'approves a pending request once and preserves the result when it is submitted again' do
    patch admin_price_change_event_path(event), params: { decision: 'approved' }
    expect(response).to redirect_to(admin_product_path(product))
    expect(product.reload.price).to eq(120)
    expect(event.reload.approved_by).to eq(administrator)
    patch admin_price_change_event_path(event), params: { decision: 'approved' }
    expect(response).to redirect_to(admin_products_path)
    expect(flash[:alert]).to eq(I18n.t('admin.catalog_design.stale_price'))
  end

  it 'rejects malformed decisions without changing the product or request' do
    patch admin_price_change_event_path(event), params: { decision: 'publish' }
    expect(response).to redirect_to(admin_products_path)
    expect(event.reload).to be_pending
    expect(product.reload.price).to eq(100)
  end

  it 'never exposes or decides a request belonging to another organization' do
    foreign = create(:product)
    other = foreign.price_change_events.create!(organization: foreign.organization, actor: administrator,
                                                new_price: 120, currency: 'MXN', reason: 'Foreign request')
    patch admin_price_change_event_path(other), params: { decision: 'approved' }
    expect(response).to have_http_status(:not_found)
    expect(other.reload).to be_pending
  end

  it 'denies decisions and configuration to an ordinary organization member' do
    operator = create(:user, :english)
    create(:organization_membership, user: operator, organization:)
    sign_in operator
    patch admin_price_change_event_path(event), params: { decision: 'approved' }
    expect(response).to have_http_status(:forbidden)
    post admin_price_lists_path, params: { price_list: { name: 'Denied', code: 'DENIED', currency: 'MXN' } }
    expect(response).to have_http_status(:forbidden)
    post admin_promotions_path, params: { promotion: { name: 'Denied', code: 'DENIED', currency: 'MXN' } }
    expect(response).to have_http_status(:forbidden)
    expect(event.reload).to be_pending
    expect(organization.price_lists).to be_empty
    expect(organization.promotions).to be_empty
  end

  it 'does not resolve commercial records after organization access is revoked' do
    reference = event.id
    administrator.organization_memberships.each { |membership| membership.update!(status: 'inactive') }
    patch admin_price_change_event_path(reference), params: { decision: 'approved' }
    expect(response).to redirect_to(new_user_session_path)
    expect(event.reload).to be_pending
  end

  it 'does not infer an organization for a new administrator without a membership' do
    unassigned = create(:user, :english, system_roles: administrator.system_roles)
    sign_in unassigned
    patch admin_price_change_event_path(event), params: { decision: 'approved' }
    expect(response).to have_http_status(:not_found)
    sign_in unassigned
    get admin_price_lists_path
    expect(response).to have_http_status(:not_found)
    sign_in unassigned
    get admin_product_path(product)
    expect(response).to redirect_to(admin_products_path)
    sign_in unassigned
    post admin_product_images_path
    expect(response).to have_http_status(:not_found)
  end

  it 'filters and clamps commercial listings without returning foreign records' do
    list = organization.price_lists.create!(name: 'Retail selected', code: 'RETAIL', currency: 'MXN', status: 'active')
    organization.price_lists.create!(name: 'Draft excluded', code: 'DRAFT', currency: 'MXN')
    get admin_price_lists_path(search: 'selected', status: 'active', page: 999)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(list.name)
    expect(response.body).not_to include('Draft excluded')
    foreign = PriceList.create!(organization: create(:organization), name: 'Foreign', code: 'FOREIGN', currency: 'MXN')
    get admin_price_list_path(foreign)
    expect(response).to have_http_status(:not_found)
  end

  it 'keeps validation errors on an active promotion without a benefit' do
    post admin_promotions_path, params: { promotion: { name: 'Missing benefit', code: 'MISSING',
                                                       currency: 'MXN', status: 'active' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Missing benefit')
    expect(organization.promotions).to be_empty
  end

  it 'prefills the organization currency and retains it while editing an inactive currency' do
    dollar = create(:currency, code: 'USD')
    create(:organization_setting, organization:, base_currency: dollar)
    get new_admin_price_list_path
    expect(Nokogiri::HTML(response.body).at_css('#price_list_currency option[selected]')['value']).to eq('USD')
    list = organization.price_lists.create!(name: 'Dollar list', code: 'USD', currency: 'USD')
    dollar.update!(active: false)
    get edit_admin_price_list_path(list)
    input = Nokogiri::HTML(response.body).at_css('#price_list_currency')
    expect(input['value']).to eq('USD')
    expect(input['readonly']).not_to be_nil
  end

  it 'supports names without Latin characters, repeated names and legacy numeric links' do
    first = Product.create!(organization:, name: '商品', code: 'UNICODE', price: 10)
    second = Product.create!(organization:, name: '商品', code: 'SECOND', price: 10)
    expect(first.slug).to eq('unicode')
    repeated = Product.create!(organization:, name: 'Coffee name', code: 'COFFEE-A', price: 10)
    duplicate = Product.create!(organization:, name: 'Coffee name', code: 'COFFEE-B', price: 10)
    expect(duplicate.slug).not_to eq(repeated.slug)
    expect(second.slug).to eq('second')
    first.slug = nil
    expect(first.to_param).to eq(first.id.to_s)
    get admin_product_path(first)
    expect(response).to have_http_status(:ok)
    expect(Product.new.to_param).to be_nil
  end

  it 'renders a validation error instead of a database failure for missing classification references' do
    post admin_products_path, params: { product: { name: 'Invalid classification', code: 'INVALID-CLASS', price: 10,
                                                   category_id: 999_999_999, sat_unit_key_id: 999_999_999,
                                                   sat_tax_id: 999_999_999 } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Invalid classification')
    expect(organization.products.where(code: 'INVALID-CLASS')).to be_empty
  end

  it 'rejects a conventional file upload whose content is not an allowed image' do
    Tempfile.create(['invalid-product', '.jpg']) do |file|
      file.write('Plain text with an image extension')
      file.rewind
      upload = Rack::Test::UploadedFile.new(file.path, 'image/jpeg', original_filename: 'product.jpg')
      post admin_products_path,
           params: { product: { name: 'Invalid media', code: 'INVALID-MEDIA', price: 10, image: upload } }
    end
    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.products.where(code: 'INVALID-MEDIA')).to be_empty
  end

  it 'accepts the validated upload token again when it identifies the product current attachment' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('app/assets/images/favicon-32x32.png'), 'image/png')
    blob = Products::ImageUpload.call(file:, organization:, user: administrator)
    product.image.attach(blob)
    token = Products::ImageUpload.token(blob, organization:, user: administrator)
    patch admin_product_path(product), params: { product: { name: 'Retained image', image_signed_id: token } }
    expect(response).to have_http_status(:redirect)
    expect(product.reload.image.blob_id).to eq(blob.id)
  end

  it 'shows an operator a pending notice and quotes the current price with the best promotion' do
    operator = create(:user, :english)
    create(:organization_membership, user: operator, organization:)
    role = create(:system_role, :system)
    create(:user_role, user: operator, system_role: role)
    GranularPermissionCatalog.sync!
    %w[products.access products.index products.show products.update].each do |code|
      create(:system_role_permission, system_role: role, permission: Permission.find_by!(code:))
    end
    sign_in operator
    patch admin_product_path(product), params: { product: { price: 120, price_change_reason: 'Supplier increase' } }
    expect(response).to redirect_to(admin_products_path)
    expect(flash[:swal_message]).to eq(I18n.t('admin.catalog_design.price_pending_notice'))
    expect(product.reload.price).to eq(100)
    expect(product.price_change_events.sole).to be_pending
    organization.promotions.create!(name: 'Ten percent', code: 'TEN', currency: 'MXN', status: 'active',
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
    get quote_admin_product_path(product)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('total' => '90.0', 'promotion' => 'Ten percent')
  end
end
