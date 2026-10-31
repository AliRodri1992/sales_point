# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier contact editor browser workflow', type: :feature, js: true do
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

  scenario 'adds a second phone using the registered Stimulus controller' do
    visit new_admin_supplier_contact_path(supplier)

    expect(page).to have_css('[data-supplier-contact-editor]')
    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 1)
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const element = document.querySelector('[data-controller="nested-phones"]')
        return Boolean(window.Stimulus.getControllerForElementAndIdentifier(element, 'nested-phones'))
      })()
    JS

    find('button[data-action="nested-phones#add"]').click

    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 2)
    phone_names = page.all('[data-nested-phones-target="items"] input[name$="[number]"]', visible: :all)
                      .map { |input| input['name'] }
    expect(phone_names.uniq.length).to eq(2)
    expect(phone_names).to all(include('[phones_attributes]'))
    expect(phone_names.any? { |name| name.include?('NEW_PHONE') }).to be(false)
    expect(page).to have_no_css('[data-nested-phones-target="empty"]:not(.hidden)', visible: :all)
  end

  scenario 'shows original mobile and office SVGs when the phone type changes' do
    visit new_admin_supplier_contact_path(supplier)
    item = find('[data-nested-phones-target="items"] > [data-phone-item]')

    expect(item).to have_css('[data-phone-kind-icon-variant="mobile"]:not(.hidden) svg')
    expect(item).to have_css('[data-phone-kind-title]', text: 'Mobile')

    page.execute_script(<<~JS)
      const type = document.querySelector('[data-phone-item] select[name$="[kind]"]')
      type.value = 'landline'
      type.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    expect(item).to have_css('[data-phone-kind-icon-variant="landline"]:not(.hidden) svg')
    expect(item).to have_css('[data-phone-kind-icon-variant="mobile"].hidden', visible: :all)
    expect(item).to have_css('[data-phone-kind-title]', text: 'Office / landline')

    page.execute_script(<<~JS)
      const type = document.querySelector('[data-phone-item] select[name$="[kind]"]')
      type.value = 'other'
      type.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    expect(item).to have_css('[data-phone-kind-icon-variant="other"]:not(.hidden) svg')
    expect(item).to have_css('[data-phone-kind-title]', text: 'Other')
  end

  scenario 'removes an unsaved phone immediately and allows adding it again' do
    visit new_admin_supplier_contact_path(supplier)
    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 1)

    find('[data-phone-item] button[data-action="nested-phones#remove"]').click
    expect(page).to have_no_css('[data-nested-phones-target="items"] > [data-phone-item]')
    expect(page).to have_css('[data-nested-phones-target="empty"]:not(.hidden)')

    find('button[data-action="nested-phones#add"]').click
    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 1)
    expect(page).to have_no_css('[data-nested-phones-target="empty"]:not(.hidden)', visible: :all)
  end

  scenario 'persists a phone added interactively to a new supplier contact' do
    visit new_admin_supplier_contact_path(supplier)

    find('input[name="contact[name]"]').set('New telephone contact')
    find('button[data-action="nested-phones#add"]').click
    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 2)

    cards = page.all('[data-nested-phones-target="items"] > [data-phone-item]')
    cards.last.find('input[name$="[number]"]').set('5512345678')
    find('input[type="submit"][value="Create contact"]').click

    expect(page).to have_current_path(admin_supplier_contacts_path(supplier), wait: 10)
    created = supplier.contacts.find_by!(name: 'New telephone contact')
    expect(created.phones.active.count).to eq(1)
    expect(created.phones.active.first.kind).to eq('mobile')
  end

  scenario 'adds and saves an additional number while editing a contact' do
    contact = create(
      :contact, contactable: supplier, name: 'Existing contact',
      phones_attributes: [
        { number: '5512345678', country_code: 'MX', kind: 'landline', primary: true }
      ]
    )
    visit edit_admin_supplier_contact_path(supplier, contact)

    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 1)
    find('button[data-action="nested-phones#add"]').click
    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 2)

    cards = page.all('[data-nested-phones-target="items"] > [data-phone-item]')
    cards.last.find('input[name$="[number]"]').set('5587654321')
    find('input[type="submit"][value="Save changes"]').click

    expect(page).to have_current_path(admin_supplier_contacts_path(supplier), wait: 10)
    expect(contact.reload.phones.active.count).to eq(2)
    expect(contact.phones.active.pluck(:kind)).to contain_exactly('landline', 'mobile')
  end

  scenario 'removes and restores an existing number before saving' do
    contact = create(
      :contact, contactable: supplier, name: 'Purchasing contact',
      phones_attributes: [
        { number: '5512345678', country_code: 'MX', kind: 'landline', primary: true }
      ]
    )
    visit edit_admin_supplier_contact_path(supplier, contact)

    card = find('[data-nested-phones-target="items"] > [data-phone-item]')
    card.find('button[data-action="nested-phones#remove"]').click

    expect(card).to have_css('[data-phone-removed-message]:not(.hidden)', text: 'This phone will be removed')
    expect(card.find('input[name$="[_destroy]"]', visible: :all).value).to eq('1')

    card.find('button[data-action="nested-phones#undoRemove"]').click

    expect(card).to have_css('[data-phone-fields]:not(.hidden)')
    expect(card.find('input[name$="[_destroy]"]', visible: :all).value).to eq('0')
    expect(page).to have_css('[data-nested-phones-target="items"] > [data-phone-item]', count: 1)
  end

  scenario 'selects a phone label suggestion and saves it with the contact' do
    visit new_admin_supplier_contact_path(supplier)

    find('input[name="contact[name]"]').set('Sales office contact')
    card = find('[data-phone-item]')
    card.find('input[name$="[number]"]').set('5512345678')

    card.find('button[data-phone-label-value="Sales"]').click

    expect(card.find('input[name$="[label]"]').value).to eq('Sales')
    expect(card.find('button[data-phone-label-value="Sales"]')['aria-pressed']).to eq('true')

    find('input[type="submit"][value="Create contact"]').click

    expect(page).to have_current_path(admin_supplier_contacts_path(supplier), wait: 10)
    contact = supplier.contacts.find_by!(name: 'Sales office contact')
    expect(contact.phones.active.find_by!(kind: 'mobile').label).to eq('Sales')
  end

  scenario 'keeps custom labels and initializes the picker on dynamically added numbers' do
    visit new_admin_supplier_contact_path(supplier)
    find('button[data-action="nested-phones#add"]').click

    card = all('[data-phone-item]').last
    card.find('button[data-phone-label-value="Support"]').click
    expect(card.find('input[name$="[label]"]').value).to eq('Support')

    card.find('input[name$="[label]"]').set('After-hours help desk')
    expect(card.find('input[name$="[label]"]').value).to eq('After-hours help desk')
    expect(card.all('button[data-phone-label-target="choice"][aria-pressed="true"]')).to be_empty

    card.find('button[data-action="phone-label#clear"]').click
    expect(card.find('input[name$="[label]"]').value).to be_empty
  end

  scenario 'keeps the unified form inside a mobile viewport' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_admin_supplier_contact_path(supplier)

    expect(page).to have_css('[data-supplier-contact-editor]')
    expect(page).to have_css('button[data-action="nested-phones#add"]', visible: true)
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const editor = document.querySelector('[data-supplier-contact-editor]')
        const bounds = editor.getBoundingClientRect()
        return bounds.left >= -1 && bounds.right <= window.innerWidth + 1
      })()
    JS
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
