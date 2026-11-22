# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Category reference reassignment', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:source) { create(:category, organization:, name: 'Old category') }
  let!(:currency) { create(:currency, code: 'MXN') }
  let!(:target) { create(:category, organization:, name: 'Replacement') }
  let!(:product) { create(:product, organization:, category: source) }
  let!(:promotion) { Promotion.create!(organization:, name: 'Category promotion', code: 'CAT-PROMO', currency: 'MXN') }
  let!(:condition) { promotion.promotion_conditions.create!(organization:, kind: :category, category: source) }

  before do
    create(:organization_membership, organization:, user: administrator)
    source.update!(status: :inactive)
    sign_in administrator
  end

  it 'offers active destinations for an inactive category and keeps its filters' do
    get "/admin/categories/#{source.id}/references",
        params: { search: source.name, status: 'inactive' }, headers: { 'Turbo-Frame' => 'category_modal' }

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    form = document.at_css('turbo-frame#category_modal form')
    expect(form).to be_present
    expect(form['data-turbo-frame']).to eq('category_modal')
    expect(form['action']).to include('status=inactive', 'search=Old+category')
    expect(document.css('select option').pluck('value')).to include(target.id.to_s)
    expect(document.css('select option').pluck('value')).not_to include(source.id.to_s)
  end

  it 'uses a full HTML submission when the reassignment screen is opened directly' do
    get references_admin_category_path(source)
    expect(response).to have_http_status(:ok)
    form = Nokogiri::HTML(response.body).at_css('form.categories-form')
    expect(form['data-turbo']).to eq('false')
    expect(form['data-turbo-frame']).to eq('_top')
    expect(form['data-categories-filter-mutation']).to eq('true')
  end

  it 'moves products and promotion conditions atomically before allowing removal' do
    patch "/admin/categories/#{source.id}/reassign", params: {
      category_reference_transfer: { target_category_id: target.id }
    }, as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('category_modal', 'categories_list')
    expect(product.reload.category_id).to eq(target.id)
    expect(condition.reload.category_id).to eq(target.id)
    expect(source.reload.in_use?).to be(false)
    expect(source.deleted_at).to be_nil
    delete admin_category_path(source)
    expect(response).to have_http_status(:found)
    expect(source.reload.deleted_at).to be_present
  end

  it 'rejects blank, identical, inactive, retired and foreign destinations without changing references' do
    inactive = create(:category, organization:, status: :inactive)
    retired = create(:category, organization:, deleted_at: Time.current)
    foreign = create(:category, organization: create(:organization))

    [nil, 'invalid-id', 9_999_999, source.id, inactive.id, retired.id, foreign.id].each do |destination|
      patch "/admin/categories/#{source.id}/reassign", params: {
        category_reference_transfer: { target_category_id: destination }
      }, headers: { 'Turbo-Frame' => 'category_modal' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('aria-invalid="true"', 'data-server-field-error')
      expect(product.reload.category_id).to eq(source.id)
      expect(condition.reload.category_id).to eq(source.id)
      expect(source.reload.deleted_at).to be_nil
    end
  end

  it 'checks the destination again after the form was opened' do
    get references_admin_category_path(source)
    expect(response).to have_http_status(:ok)
    target.update!(status: :inactive)

    patch reassign_admin_category_path(source),
          params: { category_reference_transfer: { target_category_id: target.id } },
          headers: { 'Turbo-Frame' => 'category_modal' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(product.reload.category_id).to eq(source.id)
    expect(condition.reload.category_id).to eq(source.id)
  end

  it 'rolls back product moves when a legacy promotion condition fails validation' do
    # Simulate existing invalid data so the real validation exercises transaction rollback.
    condition.update_columns(kind: 'min_quantity', quantity: 0) # rubocop:disable Rails/SkipsModelValidations

    patch "/admin/categories/#{source.id}/reassign", params: {
      category_reference_transfer: { target_category_id: target.id }
    }, headers: { 'Turbo-Frame' => 'category_modal' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.categories.references.failed', raise: true))
    expect(product.reload.category_id).to eq(source.id)
    expect(condition.reload.category_id).to eq(source.id)
  end

  it 'moves inactive references while preserving links on retired records and HTML filters' do
    source.update!(status: :active)
    retired = create(:product, organization:, category: source)
    retired.destroy!
    source.update!(status: :inactive)
    product.update!(status: :inactive)
    promotion.update!(status: :archived)

    patch reassign_admin_category_path(source, search: source.name, status: 'inactive'),
          params: { category_reference_transfer: { target_category_id: target.id } }

    expect(response).to redirect_to(admin_categories_path(search: source.name, status: 'inactive'))
    expect(product.reload.category_id).to eq(target.id)
    expect(condition.reload.category_id).to eq(target.id)
    expect(Product.with_deleted.find(retired.id).category_id).to eq(source.id)
  end

  it 'does not expose a category in another organization' do
    foreign = create(:category, organization: create(:organization))
    get "/admin/categories/#{foreign.id}/references"
    expect(response).to have_http_status(:not_found)
  end

  it 'does not reassign references from a category in another organization' do
    foreign = create(:category, organization: create(:organization))
    patch "/admin/categories/#{foreign.id}/reassign", params: {
      category_reference_transfer: { target_category_id: target.id }
    }
    expect(response).to have_http_status(:not_found)
    expect(product.reload.category_id).to eq(source.id)
  end

  it 'requires permission to update the affected catalogs rather than categories alone' do
    editor = create(:user, :english)
    role = create(:system_role, :system, code: 'category_editor')
    create(:organization_membership, organization:, user: editor)
    create(:user_role, user: editor, system_role: role)
    %w[categories.access categories.index categories.update products.access products.update].each do |code|
      permission = Permission.find_by(code:) || create(:permission, code:)
      create(:system_role_permission, system_role: role, permission:)
    end
    sign_in editor

    get "/admin/categories/#{source.id}/references"
    expect(response).to have_http_status(:forbidden)
    patch "/admin/categories/#{source.id}/reassign", params: {
      category_reference_transfer: { target_category_id: target.id }
    }
    expect(response).to have_http_status(:forbidden)
    expect(product.reload.category_id).to eq(source.id)
    expect(condition.reload.category_id).to eq(source.id)
  end

  it 'continues to block removal of an inactive category until its references are released' do
    delete admin_category_path(source, format: :turbo_stream)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.categories.references.in_use', raise: true))
    expect(source.reload.deleted_at).to be_nil

    unused = create(:category, organization:, status: :inactive)
    delete admin_category_path(unused)
    expect(response).to have_http_status(:found)
    expect(unused.reload.deleted_at).to be_present
  end
end
