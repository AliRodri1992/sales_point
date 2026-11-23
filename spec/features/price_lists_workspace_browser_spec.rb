# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Price lists workspace', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:product) { create(:product, organization:, name: 'Breakfast tea', sku: 'TEA-180', price: 20, cost: 9) }

  before do
    administrator = create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: administrator)
    create(:currency, code: 'MXN')
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'adds an active product by SKU, retains it after validation and publishes a draft with confirmation' do
    product
    visit new_admin_price_list_path
    expect(page).to have_css('#price_list_code[readonly]')
    expect(page).to have_no_select('price_list_status')
    fill_in 'price-list-product-search', with: 'TEA-180'
    find('[data-price-list-lookup-result]', text: 'Breakfast tea').send_keys(:enter)
    within('[data-price-list-row]') do
      fill_in 'List price', with: '18'
      expect(page).to have_text('50%')
    end
    click_button I18n.t('admin.catalog_design.save', locale: :en)
    expect(page).to have_css('#price_list_name[aria-invalid=true]')
    expect(page).to have_field('List price', with: /18/)
    fill_in 'price_list_name', with: 'Wholesale tea'
    click_button I18n.t('admin.catalog_design.save', locale: :en)
    expect(page).to have_css('h1', text: 'Wholesale tea')
    expect(page).to have_text(/LP-\d{6}/)
    expect(page).to have_text('Breakfast tea')
    expect(page).to have_text('Price history')
    click_button 'Activate'
    find('.swal2-confirm').click
    expect(page).to have_css('[data-price-list-status="active"]')
  end

  scenario 'removes a new row and keeps the editor keyboard accessible' do
    product
    visit new_admin_price_list_path
    search = find('#price-list-product-search')
    search.set(product.name)
    expect(page).to have_css('[data-price-list-lookup-result]')
    search.send_keys(:arrow_down, :enter)
    within('[data-price-list-row]') { click_button 'Remove' }
    expect(page).to have_no_css('[data-price-list-row]')
    expect(page).to have_css('#price-list-product-search:focus')
  end

  scenario 'retains a changed price across an invalid reason and records the corrected submission' do
    list = organization.price_lists.create!(name: 'Tea trade', currency: 'MXN')
    item = list.price_list_items.create!(product:, price: 18)
    visit edit_admin_price_list_path(list)
    fill_in 'List price', with: '15'
    click_button I18n.t('admin.catalog_design.save', locale: :en)
    expect(page).to have_css('#price_change_reason[aria-invalid=true]')
    expect(page).to have_field('List price', with: /15/)
    fill_in 'price_change_reason', with: 'Seasonal agreement'
    click_button I18n.t('admin.catalog_design.save', locale: :en)
    expect(page).to have_text('Seasonal agreement')
    expect(item.reload.price).to eq(15)
  end

  scenario 'hides costs, margins and history from an editor without those permissions' do
    list = organization.price_lists.create!(name: 'Restricted tea list', currency: 'MXN')
    list.price_list_items.create!(product:, price: 18)
    editor = create(:user, :english)
    create(:organization_membership, organization:, user: editor)
    role = create(:system_role, :system)
    create(:user_role, user: editor, system_role: role)
    GranularPermissionCatalog.sync!
    %w[access index show update].each do |action|
      permission = Permission.find_by!(code: "price_lists.#{action}")
      create(:system_role_permission, system_role: role, permission:)
    end
    login_as(editor, scope: :user)
    visit edit_admin_price_list_path(list)
    expect(page).to have_field('List price')
    expect(page).to have_no_css('[data-cost], [data-row-margin]', visible: :all)
    visit admin_price_list_path(list)
    expect(page).to have_css('h1', text: list.name)
    expect(page).to have_no_text('Gross margin')
    expect(page).to have_no_text('Price history')
    expect(page).to have_no_button('Activate')
  end

  scenario 'keeps filtered lists and removable criteria accessible on mobile and desktop' do
    wholesale = organization.price_lists.create!(name: 'Tea wholesale', currency: 'MXN', customer_segment: 'Wholesale')
    retail = organization.price_lists.create!(name: 'Coffee retail', currency: 'MXN', customer_segment: 'Retail')
    [1440, 768, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 960)
      visit admin_price_lists_path(customer_segment: 'Wholesale')
      expect(page).to have_css('details[open]')
      expect(page).to have_link(href: admin_price_list_path(wholesale), text: /\ATea wholesale\z/i)
      expect(page).to have_no_link(href: admin_price_list_path(retail))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
    within('.products-filter-chips') { find('.products-filter-chip', text: 'Wholesale').click }
    expect(page).to have_link(href: admin_price_list_path(retail), text: /\ACoffee retail\z/i)
  end
end
