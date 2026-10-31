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
    expect(phone_names).to all(exclude('NEW_PHONE'))
    expect(page).to have_no_css('[data-nested-phones-target="empty"]:not(.hidden)', visible: :all)
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
