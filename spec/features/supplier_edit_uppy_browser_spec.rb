# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier edit Uppy document uploader', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'initializes Uppy inside a single upload area on the edit documents step' do
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="5"]').click

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden) .supplier-edit-upload')
    expect(page).to have_css('.supplier-edit-upload .uppy-Dashboard-inner', wait: 20, count: 1)
    expect(page).to have_no_css('.supplier-edit-upload [data-supplier-edit-uppy-target="fallback"]',
                                visible: :all)
    expect(page).to have_no_css('.supplier-edit-upload [data-supplier-edit-uppy-target="retryButton"]:not([hidden])',
                                visible: :all)
    expect(page).to have_css('.supplier-edit-upload [data-supplier-edit-uppy-target="dashboard"]',
                             count: 1)
  end
end
