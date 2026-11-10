# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog redesign workflows', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: administrator)
    create(:user_role, user: administrator,
                       system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after do
    Warden.test_reset!
  end

  scenario 'uploads a product image locally through Uppy and saves nested commercial options' do
    visit new_admin_product_path
    expect(page).to have_css('.uppy-Dashboard-inner', count: 1, wait: 20)
    fill_in 'product_name', with: 'Browser coffee'
    fill_in 'product_code', with: 'BROWSER-COFFEE'
    fill_in 'product_price', with: 99
    click_button 'Add variant'
    within('#product-variants [data-nested-catalog-row]') do
      find('input[name$="[name]"]').set('Dark roast')
      find('input[name$="[sku]"]').set('ROAST-DARK')
      find('input[name$="[color]"]').set('Dark')
    end
    click_button 'Add presentation'
    within('#product-presentations [data-nested-catalog-row]') do
      find('input[name$="[name]"]').set('Box of six')
      find('input[name$="[units]"]').set('6')
    end
    attach_file(Rails.root.join('app/assets/images/favicon-32x32.png'), make_visible: true) do
      find('.uppy-Dashboard-browse').click
    end
    expect(page).to have_css('[data-product-upload-target="status"]', text: 'Image ready to save.', wait: 20)
    field_widths = page.all('#product-variants .catalog-field').map do |field|
      page.evaluate_script('arguments[0].getBoundingClientRect().width', field)
    end
    expect(field_widths).to all(be >= 150)
    click_button 'Create product'
    expect(page).to have_current_path(admin_products_path, ignore_query: true)
    record = organization.products.find_by!(code: 'BROWSER-COFFEE')
    expect(record.image).to be_attached
    expect(record.product_variants.sole.name).to eq('Dark roast')
    expect(record.product_presentations.sole.units).to eq(6)
  end

  scenario 'preserves language forms through validation and supports narrow screens without page overflow' do
    page.current_window.resize_to(390, 844)
    visit new_admin_language_path
    fill_in 'language_name', with: 'French'
    fill_in 'language_code', with: '12'
    fill_in 'language_flag_iso', with: 'fr'
    click_button 'Create language'
    expect(page).to have_css('[role="alert"]')
    expect(page).to have_field('language_name', with: 'French')
    fill_in 'language_code', with: 'fr'
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    click_button 'Create language'
    expect(page).to have_current_path(admin_languages_path, ignore_query: true)
    expect(page).to have_css('turbo-frame#languages_list', text: 'French')
    expect(Language.find_by!(code: 'fr').name).to eq('French')
  end
  scenario 'applies advanced product filters on mobile and restores the active URL' do
    first_category = create(:category, organization:, name: 'Beverages')
    second_category = create(:category, organization:, name: 'Office supplies')
    create(:product, organization:, category: first_category, name: 'Catalog orange tea')
    create(:product, organization:, category: second_category, name: 'Catalog printer paper')

    page.current_window.resize_to(390, 844)
    visit admin_products_path

    find('details.products-filters__advanced summary').click
    select = find('#products_category', visible: :all)
    wrapper = select.find(:xpath, '..')
    wrapper.find('button[aria-haspopup="listbox"]').click
    wrapper.find('[role="option"]', text: 'Beverages', exact_text: true).click

    click_button 'Apply filters'
    expect(page).to have_current_path(/category_id=#{first_category.id}/)
    expect(page).to have_css('details.products-filters__advanced[open]')
    expect(page).to have_css('#admin_products_list', text: 'Catalog orange tea')
    expect(page).to have_no_css('#admin_products_list', text: 'Catalog printer paper')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    within('nav.products-filter-chips') do
      find('a.products-filter-chip', text: 'Beverages').click
    end
    expect(page.current_url).not_to include('category_id=')
    expect(page).to have_css('#admin_products_list', text: 'Catalog printer paper')

    fill_in 'products_search', with: 'orange tea'
    expect(page).to have_css('#admin_products_list', text: 'Catalog orange tea')
    expect(page).to have_no_css('#admin_products_list', text: 'Catalog printer paper')
    expect(page.current_url).to include('search=orange')
    expect(page.evaluate_script('document.activeElement.id')).to eq('products_search')
  end

  scenario 'preserves sort and page size when applying advanced filters' do
    category = create(:category, organization:, name: 'Drinkware')
    create(:product, organization:, category:, name: 'Insulated cup', price: 35)

    visit admin_products_path(sort: 'products.price', direction: 'desc', per_page: '5')
    find('details.products-filters__advanced summary').click

    wrapper = find('#products_category', visible: :all).find(:xpath, '..')
    wrapper.find('button[aria-haspopup="listbox"]').click
    wrapper.find('[role="option"]', text: 'Drinkware', exact_text: true).click
    click_button 'Apply filters'

    expect(page).to have_current_path(/category_id=#{category.id}/)
    expect(page.current_url).to include('sort=products.price', 'direction=desc', 'per_page=5')
    expect(page).to have_css('#admin_products_list', text: 'Insulated cup')

    fill_in 'products_search', with: 'Insulated'
    expect(page).to have_css('#admin_products_list', text: 'Insulated cup')
    expect(page.current_url).to include('search=Insulated', 'sort=products.price', 'per_page=5')
    expect(page.evaluate_script('document.activeElement.id')).to eq('products_search')
  end

  scenario 'keeps branch and user pages usable on mobile and retains clear desktop navigation' do
    branch = create(:branch, organization:, name: 'Central branch')
    member = create(:user, :english, username: 'catalog_member')
    create(:organization_membership, user: member, organization:)
    page.current_window.resize_to(390, 844)
    paths = [admin_branches_path, new_admin_branch_path, edit_admin_branch_path(branch), admin_branch_path(branch),
             new_admin_user_path, edit_admin_user_path(member), admin_user_path(member), admin_languages_path]
    paths.each do |path|
      visit path
      expect(page).to have_css('main h1', count: 1)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
    page.current_window.resize_to(1440, 1000)
    visit new_admin_branch_path
    visit edit_admin_user_path(member)
    expect(page).to have_css('nav[aria-label="Form sections"]')
  end
end
