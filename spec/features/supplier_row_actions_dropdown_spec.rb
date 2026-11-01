# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier row actions', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    create_list(:supplier, 5, organization:)
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  def last_row_actions
    visit admin_suppliers_path(per_page: 5)
    find('tbody tr:last-child td:last-child > div')
  end

  scenario 'keeps the last row actions directly accessible on compact desktop screens' do
    page.driver.browser.manage.window.resize_to(880, 530)

    actions = last_row_actions
    actions.scroll_to(:center)
    expect(actions).to have_css('a', count: 2)
    expect(actions).to have_css('form button[data-controller~="swal-confirm"]', visible: true)
    expect(actions).to have_no_css('details[data-supplier-floating-menu]', visible: :all)

    controls = actions.all('a, form button', visible: true)
    expect(controls.size).to eq(3)
    expect(controls.all? { |control| control['aria-label'].present? }).to be(true)
  end

  scenario 'requires confirmation before removing a supplier from the visible row actions' do
    page.driver.browser.manage.window.resize_to(1400, 900)

    actions = last_row_actions
    expect(actions).to have_no_css('details', visible: :all)
    actions.find('form button[data-controller~="swal-confirm"]').click

    expect(page).to have_css('.swal2-popup', visible: true)
    find('.swal2-cancel', visible: true).click
    expect(page).to have_no_css('.swal2-popup', visible: true)
    expect(page).to have_css('tbody tr', count: 5)
  end
end
