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

  scenario 'searches live and renders a removable filter chip' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    fill_in 'category_search', with: 'groceries'

    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'groceries', wait: 10)
    expect(page).to have_css('.categories-mobile-card', text: 'Groceries', visible: :all)
  end

end
