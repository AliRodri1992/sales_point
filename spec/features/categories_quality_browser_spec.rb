# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Categories modal workflows', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, organization:, user: administrator)
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'validates required fields and saves the description from the modal' do
    visit admin_categories_path
    click_link 'New category'
    expect(page).to have_css('turbo-frame#category_modal [role="dialog"]', wait: 10)

    fill_in 'category_code', with: 'browser_category'
    click_button 'Create category'
    expect(page).to have_css('#category_name_error', wait: 10)
    expect(page).to have_css('#category_name[aria-invalid="true"]')

    fill_in 'category_name', with: 'Browser category'
    fill_in 'category_description', with: 'Browser verified description'
    click_button 'Create category'

    expect(page).to have_css('turbo-frame#categories_list', text: 'Browser category', wait: 10)
    expect(organization.categories.find_by!(code: 'browser_category').description).to eq('Browser verified description')
  end

  scenario 'uses a wider two-column form on desktop and stacks fields on narrow screens' do
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit admin_categories_path
    click_link 'New category'
    expect(page).to have_css('turbo-frame#category_modal .categories-modal', wait: 10)

    desktop = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('#category_modal .categories-modal')
        const code = document.querySelector('#category_code').getBoundingClientRect()
        const name = document.querySelector('#category_name').getBoundingClientRect()
        return { width: panel.getBoundingClientRect().width, sameRow: Math.abs(code.top - name.top) < 4 }
      })()
    JS
    expect(desktop['width']).to be_between(600, 700)
    expect(desktop['sameRow']).to be(true)

    page.driver.browser.manage.window.resize_to(390, 844)
    stacked = page.evaluate_script(<<~JS)
      (() => {
        const code = document.querySelector('#category_code').getBoundingClientRect()
        const name = document.querySelector('#category_name').getBoundingClientRect()
        const panel = document.querySelector('#category_modal .categories-modal').getBoundingClientRect()
        return { stacked: name.top > code.bottom, fits: panel.width <= window.innerWidth }
      })()
    JS
    expect(stacked['stacked']).to be(true)
    expect(stacked['fits']).to be(true)
  end

  scenario 'retains sorting after a table header click without advanced filters' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    within('table.categories-table thead') { click_link 'Name' }

    expect(page).to have_css('turbo-frame#categories_list a.categories-filter-chip', text: 'Descending', wait: 10)
    expect(page).to have_no_css('details.categories-advanced')
    expect(page).to have_css('input#category_direction[type="hidden"][value="desc"]', visible: :all, wait: 10)

    fill_in 'category_search', with: 'groceries'
    expect(page).to have_css('turbo-frame#categories_list a.categories-filter-chip', text: 'Descending', wait: 10)
  end

  scenario 'preserves an active search after creating an unrelated category' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    fill_in 'category_search', with: 'groceries'
    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'groceries', wait: 10)

    click_link 'New category'
    fill_in 'category_code', with: 'new_unrelated'
    fill_in 'category_name', with: 'Cleaning'
    click_button 'Create category'

    expect(page).to have_css('#category_search[value="groceries"]', visible: :all, wait: 10)
    expect(page).to have_css('turbo-frame#categories_list', text: 'Groceries', wait: 10)
    expect(page).to have_no_css('turbo-frame#categories_list a.categories-name-link', text: 'Cleaning')
    expect(organization.categories.find_by!(code: 'new_unrelated')).to be_present
  end

  scenario 'searches live and renders a removable filter chip' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    fill_in 'category_search', with: 'groceries'

    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'groceries', wait: 10)
    expect(page).to have_css('.categories-mobile-card', text: 'Groceries', visible: :all)
  end
end
