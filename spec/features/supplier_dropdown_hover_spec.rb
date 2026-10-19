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

  def expect_full_width_option_hover(select_name)
    select = find("select[name='#{select_name}']", visible: :all)
    dropdown = select.find(:xpath, '..')
    dropdown.find('button[aria-haspopup="listbox"]').click

    menu = dropdown.find('[role="listbox"]')
    option = menu.all('[role="option"]', minimum: 2).find do |item|
      item['aria-selected'] == 'false' && item.text.present?
    end
    expect(option).to be_present

    edges = page.evaluate_script(<<~JS, menu, option)
      const menu = arguments[0].getBoundingClientRect()
      const option = arguments[1].getBoundingClientRect()
      ({ left: option.left - menu.left, right: menu.right - option.right })
    JS

    # The one-pixel menu border must be the only inset; no padded gutters.
    expect(edges.fetch('left')).to be_within(1.1).of(1)
    expect(edges.fetch('right')).to be_within(1.1).of(1)
    expect(option[:class]).to include('rounded-none', 'hover:bg-emerald-50')

    option.hover
    expect(menu).to have_css('[role="option"]:hover')
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

    expect_full_width_option_hover('address[country_id]')
    menu = find('select[name="address[country_id]"]', visible: :all)
           .find(:xpath, '..').find('[role="listbox"]')
    expect(menu).to have_css('input[type="search"]')
    expect(menu).to have_css('[role="option"] img')
  end
end
