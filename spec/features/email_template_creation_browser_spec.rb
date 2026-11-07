# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email template creation experience', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:admin) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: admin)
    create(:user_role, user: admin, system_role: role)
    %w[access create].each do |action|
      permission = Permission.find_or_create_by!(code: "email_templates.#{action}") do |record|
        record.name = "Manage email #{action}"
        record.module_name = 'Communication'
        record.status = :active
      end
      SystemRolePermission.find_or_create_by!(system_role: role, permission:)
    end
    Warden.test_mode!
    login_as(admin, scope: :user)
  end

  after do
    page.current_window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'suggests a code without overwriting manual edits and stays responsive on mobile' do
    page.current_window.resize_to(390, 844)
    visit new_admin_email_template_path

    expect(page).to have_css('#email-template-guidance-title')
    expect(page).to have_css('img[alt="Deltín, the Delta POS mascot"]')
    fill_in 'email_template_name', with: 'Confirmación de pedido'
    expect(page).to have_field('email_template_key', with: 'confirmacion_de_pedido')
    fill_in 'email_template_key', with: 'custom_notice'
    fill_in 'email_template_name', with: 'Updated confirmation'
    expect(page).to have_field('email_template_key', with: 'custom_notice')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth + 2')).to be(true)

    click_button I18n.t('admin.email_templates.create_draft', locale: :en)

    expect(page).to have_current_path(%r{/admin/email_templates/\d+$})
    template = EmailTemplate.find_by!(key: 'custom_notice', organization:)
    expect(template.name).to eq('Updated confirmation')
    expect(template.status).to eq('draft')
    expect(template.versions.where(status: 'draft')).to exist
  end
end
