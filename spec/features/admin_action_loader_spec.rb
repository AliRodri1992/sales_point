# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deltín action progress indicator', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'uses the approved SVG mascot and hides the overlay while idle' do
    visit admin_suppliers_path

    expect(page).to have_css('#admin-action-loader[role="status"][hidden]', visible: :all)
    expect(page).to have_css('#admin-action-loader img[src*="deltin/waving"]', visible: :all)
    expect(page).to have_css('#admin-action-loader .deltin-action-progress__indicator', visible: :all)
    expect(page).to have_css('#admin-action-loader[data-controller="admin-action-loader"]', visible: :all)
  end

  scenario 'displays the requested action and dismisses on a failed Turbo request' do
    visit admin_suppliers_path

    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent("admin:action-loading", {
        detail: { message: "Opening supplier record…" }
      }))
    JS

    expect(page).to have_css('#admin-action-loader:not([hidden])', visible: true)
    expect(page).to have_css('#admin-action-loader [data-admin-action-loader-target="message"]',
                             text: 'Opening supplier record…', visible: true)

    page.execute_script('document.dispatchEvent(new Event("turbo:fetch-request-error"))')
    expect(page).to have_css('#admin-action-loader[hidden]', visible: :all)
  end

  scenario 'supports explicitly cancelling an in-progress loading indication' do
    visit admin_suppliers_path

    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent("admin:action-loading", {
        detail: { message: "Updating supplier list…" }
      }))
    JS
    expect(page).to have_css('#admin-action-loader:not([hidden])', visible: true)

    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent("admin:action-loading", { detail: { active: false } }))
    JS
    expect(page).to have_css('#admin-action-loader[hidden]', visible: :all)
  end

  scenario 'does not block the user when an unvalidated supplier form is opened' do
    visit new_admin_supplier_path

    expect(page).to have_css('form[data-controller="supplier-form"][data-loading-message]', visible: :all)
    expect(page).to have_css('#admin-action-loader[hidden]', visible: :all)
  end
end
