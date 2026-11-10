# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Categories', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }
  let!(:role) { create(:system_role, :system) }
  let!(:categories_permission) { create(:permission, code: 'categories.access') }

  before do
    create(:organization_membership, user:)
    create(:user_role, user:, system_role: role)
    create(:system_role_permission, system_role: role, permission: categories_permission)
    GranularPermissionCatalog.sync!
    codes = ['categories'].product(GranularPermissionCatalog::ACTIONS).map { |parts| parts.join('.') }
    Permission.where(code: codes).find_each do |permission|
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
    sign_in user
  end

  after do
    sign_out user
  end

  describe 'GET /admin/categories' do
    it 'forbids access when the user role no longer has categories.access' do
      role.system_role_permissions.delete_all

      get admin_categories_path

      expect(response).to have_http_status(:forbidden)
    end

    let!(:category) { create(:category, name: 'Caja', code: 'cashier') }

    before do
      create_list(:category, 15)
    end

    it 'renders the units of measure sidebar link as a collection route without an id' do
      %w[units_of_measure.access units_of_measure.index].each do |code|
        permission = Permission.find_by!(code:)
        SystemRolePermission.find_or_create_by!(system_role: role, permission:)
      end

      get admin_categories_path

      expect(response).to have_http_status(:ok)
      sidebar = Nokogiri::HTML(response.body)
      unit_link = sidebar.at_css('a[href="/admin/units_of_measure"]')
      expect(unit_link).to be_present
      expect(unit_link['aria-label']).to eq(I18n.t('admin.units_of_measure.index.title'))
    end

    it 'returns a paginated list with at least 10 items per page' do
      get admin_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.categories.index.total_count',
                                              count: Category.not_deleted.count))
    end

    it 'shows the total count of categories (not just page count)' do
      get admin_categories_path

      total = Category.not_deleted.count
      expect(response.body).to include(I18n.t('admin.categories.index.total_count', count: total))
    end

    it 'respects the per_page query param' do
      get admin_categories_path(per_page: 5)

      expect(response).to have_http_status(:ok)
    end

    it 'filters by search query on name or code' do
      get admin_categories_path(search: 'Caja')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Caja')
    end

    it 'filters by status' do
      get admin_categories_path(status: 'active')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by name in descending order when direction=desc' do
      get admin_categories_path(sort: 'name', direction: 'desc')

      expect(response).to have_http_status(:ok)
    end

    it 'sorts by code column' do
      get admin_categories_path(sort: 'code')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /admin/categories/new' do
    it 'renders the new category form' do
      get new_admin_category_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="category[name]"')
    end
  end

  describe 'Category audit regressions' do
    it 'renders a standalone form without duplicate modal frames' do
      get new_admin_category_path

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.css('turbo-frame#category_modal').size).to eq(1)
      expect(document.at_css('textarea[name="category[description]"]')).to be_present
      expect(document.at_css('input[name="category[code]"]')['aria-describedby']).to include('category_code_hint')
    end

    it 'keeps filter-empty results distinct from an empty catalog' do
      create(:category, name: 'Existing', code: 'existing')
      get admin_categories_path(search: 'no-such-category')
      expect(response.body).to include(I18n.t('admin.categories.index.no_results'))
      expect(response.body).not_to include(I18n.t('admin.categories.index.empty_title'))
    end

    it 'treats LIKE wildcard characters as literal search text' do
      create(:category, name: 'Existing', code: 'existing')
      get admin_categories_path(search: '%')
      expect(response.body).to include(I18n.t('admin.categories.index.no_results'))
    end

    it 'persists the description and renders it in the detail page' do
      attributes = { name: 'Food', code: 'food', description: 'Fresh groceries and produce' }
      post admin_categories_path, params: { category: attributes }
      category = Category.find_by!(code: 'food')
      expect(category.description).to eq('Fresh groceries and produce')
      get admin_category_path(category)
      expect(response.body).to include('Fresh groceries and produce')
    end
  end

  describe 'POST /admin/categories' do
    it 'sends a "created" notification to the current user' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: 'test_category', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('created')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("categories_catalog_#{user.organization_memberships.first.organization_id}")

      post admin_categories_path(format: :turbo_stream),
           params: { category: { name: 'Test Category', code: 'test_category' } }
    end

    it 'redirects after creating a category through HTML' do
      post admin_categories_path,
           params: { category: { name: 'HTML Category', code: 'html_category' } }

      expect(response).to redirect_to(admin_categories_path)
      expect(Category.find_by!(code: 'html_category')).to be_present
    end

    it 'defaults the status to active when not provided' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: 'test_category' } }
      end.to change(Category, :count).by(1)

      expect(Category.find_by(code: 'test_category').status).to eq('active')
    end

    it 'does not persist the category when name is blank' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: '', code: 'test_category' } }
      end.not_to change(Category, :count)
    end

    it 'does not persist the category when code is blank' do
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: '' } }
      end.not_to change(Category, :count)
    end

    it 'displays field errors for invalid records without discarding entered values' do
      post admin_categories_path, params: { category: { name: '', code: 'kept_code' } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('kept_code', 'aria-invalid="true"', 'category_name_error')
    end

    it 'refuses descriptions over 500 characters' do
      attributes = { name: 'Long', code: 'long', description: 'x' * 501 }
      post admin_categories_path, params: { category: attributes }
      expect(response).to have_http_status(:unprocessable_content)
      expect(Category.find_by(code: 'long')).to be_nil
    end

    it 'does not persist the category when code is already taken' do
      create(:category, code: 'test_category')
      expect do
        post admin_categories_path(format: :turbo_stream),
             params: { category: { name: 'Test Category', code: 'test_category' } }
      end.not_to change(Category, :count)
    end
  end

  describe 'PATCH /admin/categories/:id' do
    let!(:category) { create(:category, name: 'Old Name', code: 'old_code') }

    it 'sends an "updated" notification to the current user' do
      expect do
        patch admin_category_path(category, format: :turbo_stream),
              params: { category: { name: 'New Name', code: 'old_code', status: 'active' } }
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('updated')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("categories_catalog_#{user.organization_memberships.first.organization_id}")

      patch admin_category_path(category, format: :turbo_stream),
            params: { category: { name: 'New Name', code: 'old_code' } }
    end

    it 'redirects after updating a category through HTML' do
      patch admin_category_path(category),
            params: { category: { name: 'HTML Updated', code: 'old_code' } }

      expect(response).to redirect_to(admin_categories_path)
      expect(category.reload.name).to eq('HTML Updated')
    end

    it 'updates the category name' do
      patch admin_category_path(category, format: :turbo_stream),
            params: { category: { name: 'New Name', code: 'old_code' } }

      expect(category.reload.name).to eq('New Name')
    end

    it 'does not update the category when name is blank' do
      patch admin_category_path(category, format: :turbo_stream),
            params: { category: { name: '', code: 'old_code' } }

      expect(category.reload.name).to eq('Old Name')
    end
  end

  describe 'DELETE /admin/categories/:id' do
    let!(:category) { create(:category, name: 'ToDelete', code: 'del_category') }

    it 'protects categories referenced by active products' do
      organization = user.organization_memberships.first.organization
      create(:product, organization:, category:)
      delete admin_category_path(category)

      expect(response).to have_http_status(:see_other)
      expect(category.reload.deleted_at).to be_nil
      expect(flash[:alert]).to eq(I18n.t('admin.categories.in_use'))
    end

    it 'shows a translated error in Turbo Stream for an in-use category' do
      organization = user.organization_memberships.first.organization
      create(:product, organization:, category:)
      delete admin_category_path(category, format: :turbo_stream)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('categories_alert', I18n.t('admin.categories.in_use'))
      expect(category.reload.deleted_at).to be_nil
    end

    it 'sends a "destroyed" notification to the current user' do
      expect do
        delete admin_category_path(category, format: :turbo_stream)
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.params[:action]).to eq('destroyed')
    end

    it 'stores the actor user in the notification params' do
      delete admin_category_path(category, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.params[:user]).to eq(user)
    end

    it 'keeps the soft-deleted category record accessible on the notification' do
      delete admin_category_path(category, format: :turbo_stream)

      notification = Noticed::Notification.last
      expect(notification.record).to be_a(Category)
      expect(notification.record.code).to eq('del_category')
    end

    it 'broadcasts the updated catalog to subscribed clients' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with("categories_catalog_#{user.organization_memberships.first.organization_id}")

      delete admin_category_path(category, format: :turbo_stream)
    end

    it 'redirects after deleting a category through HTML' do
      delete admin_category_path(category)

      expect(response).to redirect_to(admin_categories_path)
      expect(Category.with_deleted.find(category.id).deleted_at).to be_present
    end

    it 'soft-deletes the category' do
      expect do
        delete admin_category_path(category, format: :turbo_stream)
      end.to change { Category.not_deleted.count }.by(-1)
      expect(Category.with_deleted.find(category.id).deleted_at).not_to be_nil
    end

    it 'appears in user.notifications even when the category is soft-deleted' do
      delete admin_category_path(category, format: :turbo_stream)

      notification = user.notifications.find_by(
        noticed_events: { record_type: 'Category', record_id: category.id }
      )
      expect(notification).to be_present
      expect(notification.params[:action]).to eq('destroyed')
    end
  end

  describe 'Category catalog redesign regressions' do
    let(:organization) { user.organization_memberships.first.organization }

    it 'renders accessible filter controls and five desktop columns' do
      create(:category, organization:, name: 'Groceries', code: 'groceries',
                        description: 'Food and pantry products')

      get admin_categories_path

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('section.categories-filter-panel')).to be_present
      expect(document.at_css('input#category_search')).to be_present
      expect(document.at_css('select#category_status')).to be_present
      expect(document.at_css('details.categories-advanced')).to be_nil
      expect(document.at_css('input#category_sort[type="hidden"]')).to be_present
      expect(document.at_css('input#category_direction[type="hidden"]')).to be_present
      expect(document.css('table.categories-table thead th').size).to eq(5)
      expect(document.css('table.categories-table tbody').text).to include('Food and pantry products')
    end

    it 'keeps page ordering stable for categories with identical names' do
      categories = Array.new(12) do |index|
        create(:category, organization:, name: 'Duplicate', code: "same_name_#{index}")
      end

      ids = [1, 2].flat_map do |page_number|
        get admin_categories_path(sort: 'name', direction: 'asc', page: page_number)
        links = Nokogiri::HTML(response.body).css('table.categories-table tbody a.categories-name-link')
        links.map { |link| link['href'].match(%r{/categories/(\d+)})[1].to_i }
      end

      expect(ids).to eq(categories.map(&:id).sort)
    end

    it 'announces the active table sort direction to assistive technology' do
      create(:category, organization:, name: 'One', code: 'one')

      get admin_categories_path(sort: 'code', direction: 'desc')

      headings = Nokogiri::HTML(response.body).css('th[aria-sort]')
      expect(headings.size).to eq(1)
      expect(headings.first['aria-sort']).to eq('descending')
      expect(headings.first.text).to include(I18n.t('admin.categories.index.columns.code'))
    end

    it 'retains filters in category navigation and edit form URLs' do
      category = create(:category, organization:, name: 'Groceries', code: 'groceries')
      filters = { search: 'Groceries', status: 'active', sort: 'name', direction: 'desc' }

      get admin_categories_path(filters)

      document = Nokogiri::HTML(response.body)
      create_link = document.at_css('a.categories-primary-button')
      edit_link = document.at_css('a[aria-label*="Groceries"][href*="edit"]')
      expect(create_link['href']).to include('search=Groceries', 'status=active')
      expect(edit_link['href']).to include('search=Groceries', 'status=active')

      get edit_admin_category_path(category, filters)
      edit_form = Nokogiri::HTML(response.body).at_css('form.categories-form')
      expect(edit_form['action']).to include('search=Groceries', 'status=active')
    end

    it 'keeps an active search on the results after creating another category via Turbo' do
      create(:category, organization:, name: 'Groceries', code: 'groceries')

      post admin_categories_path(search: 'groceries', status: 'active', format: :turbo_stream),
           params: { category: { name: 'Cleaning', code: 'cleaning' } }

      expect(response).to have_http_status(:ok)
      content = response.body
      expect(content).to include('Groceries', 'search=groceries')
      expect(content).not_to include('categories-name-link">Cleaning')
    end

    it 'provides mobile cards retaining the category description' do
      create(:category, organization:, name: 'Personal Care', code: 'personal_care',
                        description: 'Daily hygiene essentials')

      get admin_categories_path

      document = Nokogiri::HTML(response.body)
      expect(document.at_css('ul.categories-mobile-list')).to be_present
      expect(document.css('.categories-mobile-card').map(&:text).join).to include('Daily hygiene essentials')
    end

    it 'keeps the table-header sort available without advanced filters' do
      create(:category, organization:, name: 'Visible', code: 'visible')
      get admin_categories_path(sort: 'name', direction: 'desc')

      document = Nokogiri::HTML(response.body)
      expect(document.at_css('details.categories-advanced')).to be_nil
      expect(document.at_css('input#category_sort')['value']).to eq('name')
      expect(document.at_css('input#category_direction')['value']).to eq('desc')
      expect(document.at_css('th a[href*="sort=name"]')).to be_present
    end

    it 'shows descending name order as a removable sorting chip' do
      get admin_categories_path(sort: 'name', direction: 'desc')

      document = Nokogiri::HTML(response.body)
      expect(document.css('a.categories-filter-chip').size).to eq(1)
      expect(document.at_css('a.categories-filter-chip').text).to include(
        I18n.t('admin.categories.index.filters.descending')
      )
      expect(document.at_css('.categories-directory')['data-categories-current-direction']).to eq('desc')
    end

    it 'ignores unsupported status values rather than showing a misleading empty catalog' do
      create(:category, organization:, name: 'Visible category', code: 'visible_category')
      get admin_categories_path(status: 'unsupported')

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.css('table.categories-table tbody tr')).not_to be_empty
      expect(document.at_css('a.categories-filter-chip')).to be_nil
    end

    it 'links category names to an authorized modal on desktop and mobile' do
      category = create(:category, organization:, name: 'Wellness', code: 'wellness')

      get admin_categories_path

      document = Nokogiri::HTML(response.body)
      links = document.css("a.categories-name-link[href='/admin/categories/#{category.id}']")
      expect(links.size).to eq(2)
      expect(links.all? { |link| link['data-turbo-frame'] == 'category_modal' }).to be(true)
    end

    it 'shows individual removable search and status chips' do
      create(:category, organization:, name: 'Clothing', code: 'clothing')

      get admin_categories_path(search: 'clothing', status: 'active')

      document = Nokogiri::HTML(response.body)
      chips = document.css('a.categories-filter-chip')
      expect(chips.size).to eq(2)
      expect(chips.map { |link| link.attribute('href').value }.join).to include('status=active', 'search=clothing')
      expect(document.at_css('a.categories-clear-filters')).to be_present
    end
  end
end
