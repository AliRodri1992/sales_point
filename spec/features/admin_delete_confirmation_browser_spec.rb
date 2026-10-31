# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Delta POS confirmation dialog', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'displays a compact, contextual confirmation and does not delete when cancelled' do
    contact = create(:contact, contactable: supplier, name: 'Mariana Sales')
    visit admin_supplier_contacts_path(supplier)

    find('article', text: contact.name).find('form[method="post"] button', text: 'Delete').click

    expect(page).to have_css('.swal2-popup.delta-confirm-popup.delta-confirm-danger', visible: true)
    popup = find('.swal2-popup.delta-confirm-popup')
    expect(popup).to have_css('.delta-confirm-title', text: 'Remove this record?')
    expect(popup).to have_css('.delta-confirm-description', text: contact.name)
    expect(popup).to have_css('.delta-confirm-description', text: 'It will be removed from the active list.')
    expect(popup).to have_css('.delta-confirm-icon svg[aria-hidden="true"]')
    expect(popup).to have_button('Cancel')
    expect(popup).to have_button('Yes, remove')

    popup.find('button.delta-confirm-cancel').click
    expect(page).to have_no_css('.swal2-popup.delta-confirm-popup', visible: :all)
    expect(contact.reload.deleted_at).to be_nil
  end

  scenario 'deletes only after explicit confirmation' do
    contact = create(:contact, contactable: supplier, name: 'Contact to archive')
    visit admin_supplier_contacts_path(supplier)

    find('article', text: contact.name).find('form[method="post"] button', text: 'Delete').click
    find('.swal2-popup.delta-confirm-popup .delta-confirm-accept').click

    expect(page).to have_current_path(admin_supplier_contacts_path(supplier), wait: 10)
    expect(contact.reload.deleted_at).to be_present
  end

  scenario 'uses the same dialog when deleting a supplier from the listing' do
    supplier
    visit admin_suppliers_path

    row = find('tbody tr', text: supplier.name)
    row.find('form button[type="submit"]', match: :first).click

    expect(page).to have_css('.swal2-popup.delta-confirm-popup.delta-confirm-danger')
    popup = find('.swal2-popup.delta-confirm-popup')
    expect(popup).to have_css('.delta-confirm-description', text: supplier.name)
    popup.find('.delta-confirm-cancel').click

    expect(supplier.reload.deleted_at).to be_nil
  end

  scenario 'uses a neutral design for non-destructive confirmations' do
    visit admin_supplier_contacts_path(supplier)

    page.execute_script(<<~JS)
      window.Turbo.config.forms.confirm('Set this contact as primary?')
    JS

    expect(page).to have_css('.swal2-popup.delta-confirm-popup.delta-confirm-neutral')
    expect(page).to have_css('.delta-confirm-title', text: 'Confirm this action?')
    expect(page).to have_button('Confirm')
    find('.swal2-popup.delta-confirm-popup .delta-confirm-cancel').click
  end

  scenario 'fits a narrow mobile viewport without overflowing' do
    contact = create(:contact, contactable: supplier, name: 'Mobile contact')
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_supplier_contacts_path(supplier)

    find('article', text: contact.name).find('form[method="post"] button', text: 'Delete').click
    expect(page).to have_css('.swal2-popup.delta-confirm-popup')

    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const dialog = document.querySelector('.swal2-popup.delta-confirm-popup')
        const box = dialog.getBoundingClientRect()
        return box.left >= 0 && box.right <= window.innerWidth &&
          dialog.querySelectorAll('.swal2-actions button').length === 2
      })()
    JS
    find('.swal2-popup.delta-confirm-popup .delta-confirm-cancel').click
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
