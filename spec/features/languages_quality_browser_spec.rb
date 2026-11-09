# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Languages administration quality', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, organization:, user: administrator)
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'shows a field-level error when an unsupported language is activated' do
    visit admin_languages_path
    click_link 'New language'

    fill_in 'language_name', with: 'Français'
    fill_in 'language_code', with: 'fr'
    fill_in 'language_flag_iso', with: 'fr'
    click_button 'Create language'

    expect(page).to have_css('#language_code_error', wait: 10)
    expect(page).to have_css('#language_code[aria-invalid="true"]')
    expect(page).to have_field('language_name', with: 'Français')
    expect(Language.find_by(code: 'fr')).to be_nil
  end

  scenario 'protects persisted identifiers and uses the Delta status dropdown' do
    visit edit_admin_language_path(administrator.language)

    expect(page).to have_css('#language_code[readonly]')
    expect(page).to have_css('[data-controller="delta-select"]')
    expect(page).to have_css('#language_status', visible: :all)
  end
end
