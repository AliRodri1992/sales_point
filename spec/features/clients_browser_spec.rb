# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Clients redesigned catalog', type: :feature, js: true do
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

  after { Warden.test_reset! }

  scenario 'shows validation feedback and persists a customer from the redesigned form' do
    visit new_admin_client_path
    expect(page).to have_css('#client-identity-heading', wait: 10)
    expect(page).to have_css('#client-contact-heading')
    expect(page).to have_css('#client-fiscal-heading')
    expect(page).to have_css('#client-commercial-heading')

    fill_in 'client_code', with: 'BRW-CLI-001'
    click_button 'Create customer'
    expect(page).to have_css('#client_name_error', wait: 10)
    expect(page).to have_field('client_code', with: 'BRW-CLI-001')

    fill_in 'client_name', with: 'Browser Customer'
    fill_in 'client_email', with: 'customer@example.test'
    click_button 'Create customer'
    expect(page).to have_current_path(admin_clients_path, ignore_query: true, wait: 10)
    expect(page).to have_css('turbo-frame#clients_list', text: 'Browser Customer', wait: 10)
    expect(Client.find_by!(code: 'BRW-CLI-001').email).to eq('customer@example.test')
  end

  scenario 'preserves the list and editor inside small screens' do
    [320, 390, 768, 1440].each do |width|
      page.current_window.resize_to(width, 900)
      visit admin_clients_path
      expect(page).to have_css('main h1', text: 'Customers')
      expect(page).to have_css('#clients-filters-title')
      expect(page).to have_css('#clients_list')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

      visit new_admin_client_path
      expect(page).to have_css('#client-identity-heading')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
