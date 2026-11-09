# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Clients directory UX', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, user: administrator, organization:)
    Warden.test_mode!
    login_as(administrator, scope: :user)
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'shows field-level errors and creates a client from the structured form' do
    visit admin_clients_path
    expect(page).to have_css('#clients-search')
    expect(page).to have_css('#clients-credit', visible: :all)
    find('main > header a', text: 'New customer').click
    expect(page).to have_css('#client-identity-heading')
    expect(page).to have_css('#client-fiscal-heading')

    fill_in 'client_code', with: 'WEB-NEW'
    click_button 'Create customer'
    expect(page).to have_css('#client_name_error', wait: 10)
    expect(page).to have_css('#client_name[aria-invalid="true"]')
    expect(page).to have_field('client_code', with: 'WEB-NEW')

    fill_in 'client_name', with: 'Browser customer'
    fill_in 'client_notes', with: 'Browser note'
    click_button 'Create customer'
    expect(page).to have_current_path(admin_clients_path, wait: 10)
    expect(page).to have_css('tbody', text: 'Browser customer')
    expect(Client.find_by!(code: 'WEB-NEW').notes).to eq('Browser note')
  end

  scenario 'keeps filters accessible and the directory in a scroll container on mobile' do
    page.driver.browser.manage.window.resize_to(390, 844)
    create(:client, name: 'Mobile client')
    visit admin_clients_path
    expect(page).to have_css('main h1', text: 'Customers')
    expect(page).to have_css('#clients-search')
    expect(page).to have_css('.overflow-x-auto table', text: 'Mobile client')
    expect(page).to have_css('main > header a', text: 'New customer')
  end
end
