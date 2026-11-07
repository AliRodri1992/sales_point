# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog lifecycle safeguards', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:product) { create(:product, organization:, price: 100) }

  before do
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  it 'preserves both inventory and branch history when deletion is requested' do
    branch = create(:branch, organization:)
    inventory = create(:inventory, organization:, branch:, product:, stock: 10)
    delete admin_branch_path(branch)
    expect(response).to redirect_to(admin_branch_path(branch))
    expect(branch.reload.deleted_at).to be_nil
    delete admin_product_path(product)
    expect(response).to redirect_to(admin_product_path(product))
    expect(product.reload.deleted_at).to be_nil
    expect(inventory.reload.stock).to eq(10)
    patch admin_branch_path(branch), params: { branch: { status: false } }
    expect(branch.reload.status).to be(false)
    patch admin_product_path(product), params: { product: { status: 'inactive' } }
    expect(product.reload).to be_inactive
  end

  it 'handles invalid multipart forms while preserving their uploaded image for resubmission' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('app/assets/images/favicon-32x32.png'), 'image/png')
    post admin_products_path, params: { product: { name: '', code: 'WITH-IMAGE', price: 10, image: file } }
    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    signed_id = document.at_css('input[name="product[image_signed_id]"]')['value']
    blob = Products::ImageUpload.find_signed(signed_id, organization:, user: administrator)
    expect(blob.metadata['purpose']).to eq('product_image')
    post admin_products_path, params: { product: { name: 'Retained image', code: 'WITH-IMAGE', price: 10,
                                                   image: '', image_signed_id: signed_id } }
    expect(response).to have_http_status(:redirect)
    expect(organization.products.find_by!(code: 'WITH-IMAGE').image.blob).to eq(blob)
  end

  it 'retains a legacy attachment during an unrelated edit and rejects another uploader ownership' do
    Rails.root.join('app/assets/images/favicon-32x32.png').open('rb') do |file|
      product.image.attach(io: file, filename: 'legacy.png')
    end
    original = product.image.blob
    patch admin_product_path(product), params: { product: { name: 'Renamed', image_signed_id: original.signed_id } }
    expect(response).to have_http_status(:redirect)
    expect(product.reload.image.blob).to eq(original)
    other_user = create(:user)
    file = Rack::Test::UploadedFile.new(Rails.root.join('app/assets/images/favicon-32x32.png'), 'image/png')
    blob = Products::ImageUpload.call(file:, organization:, user: other_user)
    patch admin_product_path(product), params: { product: { image_signed_id: Products::ImageUpload.token(blob, organization:, user: other_user) } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(product.reload.image.blob).to eq(original)
  end

  it 'only permits uploads against a product in the current tenant' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('app/assets/images/favicon-32x32.png'), 'image/png')
    post admin_product_images_path(product_id: product.id), params: { file: }
    expect(response).to have_http_status(:created)
    foreign = create(:product)
    post admin_product_images_path(product_id: foreign.id), params: { file: }
    expect(response).to have_http_status(:not_found)
    post admin_product_images_path, params: {}
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects unsupported and inactive locale switching without changing the user preference' do
    original = administrator.language
    create(:language, code: 'fr', name: 'French', flag_iso: 'fr')
    patch '/language', params: { language: 'fr' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(administrator.reload.language).to eq(original)
    create(:language, code: 'ko', name: 'Korean', flag_iso: 'kr', status: 'inactive')
    patch '/language', params: { language: 'ko' }
    expect(response).to have_http_status(:not_found)
    expect(administrator.reload.language).to eq(original)
    patch '/language', params: { language: 'en' }
    expect(response).to have_http_status(:ok)
    expect(administrator.reload.language.code).to eq('en')
  end

  it 'uses a supported active locale when the saved preference is unavailable' do
    administrator.language.update!(status: 'inactive')
    create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    get admin_languages_path
    expect(Nokogiri::HTML(response.body).at_css('html')['lang']).to eq('es')
    expect(response.body).to include('Idiomas')
  end

  it 'renders new, edit and show user screens with navigation and retained inactive roles' do
    member = create(:user, :english)
    create(:organization_membership, organization:, user: member)
    role = create(:system_role, :system, name: 'Retained operator')
    create(:user_role, user: member, system_role: role)
    role.status = 'inactive'
    role.save!(context: :status_transition)
    [new_admin_user_path, edit_admin_user_path(member), admin_user_path(member)].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('translation_missing')
    end
    expect(response.body).to include('Retained operator')
  end
  it 'deletes unused options together and allows reuse of a retired canonical barcode' do
    product.update!(barcode: 'OLD-CODE')
    variant = product.product_variants.create!(name: 'Blue', sku: 'DELETE-BLUE')
    presentation = product.product_presentations.create!(name: 'Box', units: 6)
    delete admin_product_path(product)
    expect(response).to have_http_status(:redirect)
    expect(ProductVariant.find_by(id: variant.id)).to be_nil
    expect(ProductPresentation.find_by(id: presentation.id)).to be_nil
    replacement = create(:product, organization:, barcode: 'OLD-CODE')
    expect(replacement.product_barcodes.sole.value).to eq('OLD-CODE')
  end

  it 'renders translated catalog forms without missing text in Spanish, English and Korean' do
    %w[es en ko].each do |locale|
      language = Language.find_by(code: locale) || create(:language, code: locale, name: locale, flag_iso: 'us')
      administrator.update!(language:)
      [new_admin_product_path, admin_product_path(product), new_admin_branch_path,
       new_admin_language_path, new_admin_user_path].each do |path|
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('translation_missing')
        document = Nokogiri::HTML(response.body)
        expect(document.at_css('html')['lang']).to eq(locale)
        expect(document.at_css('title').text).not_to eq(I18n.t('admin.dashboard.index.title'))
      end
    end
  end
  it 'retains the saved classification when its category is no longer selectable' do
    category = create(:category, name: 'Archived category', status: 'inactive')
    product.update!(category:)
    get edit_admin_product_path(product)
    option = Nokogiri::HTML(response.body).at_css("#product_category_id option[value='#{category.id}']")
    expect(option['selected']).not_to be_nil
    expect(option.text).to eq('Archived category')
  end
  it 'rejects default Active Storage tokens even when client-provided metadata imitates a validated product upload' do
    path = Rails.root.join('app/assets/images/favicon-32x32.png')
    blob = path.open('rb') do |file|
      ActiveStorage::Blob.create_and_upload!(io: file, filename: 'untrusted.png',
                                             metadata: { organization_id: organization.id,
                                                         uploaded_by_id: administrator.id, purpose: 'product_image' })
    end
    post admin_products_path, params: { product: { name: 'Forged provenance', code: 'FORGED', price: 10,
                                                   image_signed_id: blob.signed_id } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(organization.products.where(code: 'FORGED')).not_to exist
  end
end
