# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dropdown option hover', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  def open_dropdown(name)
    dropdown = find("select[name='#{name}']", visible: :all).find(:xpath, '..')
    dropdown.find('button[aria-haspopup="listbox"]').click
    expect(dropdown).to have_css('button[aria-expanded="true"]')
    dropdown
  end

  def full_width_option?(option)
    page.evaluate_script(<<~JS, option)
      (function(row) {
        const menu = row.closest('[role="listbox"]')
        const list = menu.getBoundingClientRect()
        const item = row.getBoundingClientRect()
        const left = list.left + menu.clientLeft
        const right = left + menu.clientWidth
        return Math.abs(item.left - left) < 2 && Math.abs(item.right - right) < 2
      })(arguments[0])
    JS
  end

  def expect_full_width_option_hover(select_name)
    dropdown = open_dropdown(select_name)
    expect(dropdown).to have_css('button[aria-expanded="true"]')
    option = dropdown.find('[role="option"][aria-selected="false"]')
    expect(option[:class]).to include('rounded-none', 'delta-select-option')
    expect(full_width_option?(option)).to be(true)

    option.hover
    expect(dropdown).to have_css('[role="option"]:hover')
    page.execute_script(<<~JS, dropdown)
      const option = arguments[0].querySelector('[role="option"][aria-selected="false"]')
      option.dataset.stabilityMarker = 'hover'
      arguments[0].querySelector('button[aria-haspopup="listbox"]').focus()
    JS
    expect(dropdown).to have_css('[role="option"][data-stability-marker="hover"]')
    expect_selected_state_contrast(dropdown, option)
    dropdown
  end

  def expect_selected_state_contrast(dropdown, hovered_option)
    selected = dropdown.find('[role="option"][aria-selected="true"]')
    expect(selected.native.css_value('background-color')).not_to eq(hovered_option.native.css_value('background-color'))
  end

  scenario 'highlights a whole fiscal regime row, including space beyond the label' do
    create(:sat_fiscal_regime, code: '997', description: 'Fiscal regime with a long description',
                               valid_from: Date.yesterday, valid_to: Date.tomorrow)
    visit new_admin_supplier_path
    find('input[name="supplier[code]"]').set('SUP-DROPDOWN-HOVER')
    find('input[name="supplier[name]"]').set('Supplier dropdown hover')
    find('[data-action="supplier-form#next"]').click

    expect_full_width_option_hover('supplier[sat_fiscal_regime_id]')
  end

  scenario 'highlights a whole country row without losing its flag or search' do
    Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX')
    visit new_admin_supplier_address_path(supplier)

    dropdown = expect_full_width_option_hover('address[country_id]')
    expect(dropdown).to have_css('[role="listbox"] input[type="search"]')
    expect(dropdown).to have_css('[role="option"] img')

    search = dropdown.find('[role="listbox"] input[type="search"]')
    search.set('mex')
    expect(dropdown).to have_css('button[aria-expanded="true"]')
    expect(dropdown).to have_css('[role="option"]:not([hidden]) img')
    expect(dropdown).to have_css('[role="option"]:not([hidden])', text: /México|Mexico/)
    search.set('')
    expect(dropdown).to have_css('[role="option"][aria-selected="false"]')
  end
end
