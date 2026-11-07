# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog redesign boundaries', type: :request do
  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:administrator) { create(:user, :english, system_roles: [role]) }

  before do
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  it 'lists only branches in the current organization and does not expose a foreign branch' do
    own = create(:branch, organization:, name: 'Own branch')
    foreign = create(:branch, name: 'Foreign branch')
    get admin_branches_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own.name)
    expect(response.body).not_to include(foreign.name)
    get admin_branch_path(foreign)
    expect(response).to have_http_status(:not_found)
  end

  it 'filters branches by name and status while clamping an out of range page' do
    create(:branch, organization:, name: 'Warehouse', status: false)
    create(:branch, organization:, name: 'Shop', status: true)
    get admin_branches_path, params: { search: 'Warehouse', status: 'inactive', page: 100 }
    expect(response.body).to include('Warehouse')
    list = Nokogiri::HTML(response.body).at_css('turbo-frame#branches_list').text
    expect(list).not_to include('Shop')
    expect(response).to have_http_status(:ok)
  end

  it 'keeps inactive languages visible in management and normalizes ISO codes' do
    language = create(:language, name: 'French', code: ' FR ', flag_iso: ' FR ', status: 'inactive')
    get admin_languages_path(status: 'inactive')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('French')
    expect(language.code).to eq('fr')
    expect(language.flag_iso).to eq('fr')
    expect(build(:language, code: '12')).not_to be_valid
  end

  it 'renders full page product create, edit and show screens with safe zero-price margins' do
    product = create(:product, organization:, price: 0, cost: 10)
    [new_admin_product_path, edit_admin_product_path(product), admin_product_path(product)].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('translation_missing')
    end
  end

  it 'uploads an identified image into Active Storage and retains all form values on a rejected attachment' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('app/assets/images/favicon-32x32.png'), 'image/png')
    post admin_product_images_path, params: { file: }
    expect(response).to have_http_status(:created)
    token = response.parsed_body.fetch('signed_id')
    blob = Products::ImageUpload.find_signed(token, organization:, user: administrator)
    expect(blob.metadata).to include('organization_id' => organization.id, 'uploaded_by_id' => administrator.id)
    post admin_products_path,
         params: { product: { name: 'New coffee', code: 'COFFEE', price: 20, image: token } }
    expect(response).to have_http_status(:redirect)
    expect(Product.find_by!(code: 'COFFEE').image.blob).to eq(blob)
    post admin_products_path,
         params: { product: { name: 'Retained value', code: 'SECOND', price: 20, image: 'forged' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Retained value')
  end

  it 'rejects signed images belonging to another organization and unsupported file content' do
    metadata = { organization_id: create(:organization).id, uploaded_by_id: administrator.id, purpose: 'product_image' }
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('invalid'), filename: 'image.png', metadata:)
    post admin_products_path,
         params: { product: { name: 'Other image', code: 'OTHER', price: 10, image: blob.signed_id } }
    expect(response).to have_http_status(:unprocessable_content)
    text_file = Rack::Test::UploadedFile.new(Rails.root.join('README.md'), 'text/plain')
    post admin_product_images_path, params: { file: text_file }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Product.find_by(code: 'OTHER')).to be_nil
  end
end
