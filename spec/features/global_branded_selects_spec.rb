# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Global branded select dropdowns', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  def enhanced_select(name)
    original = find("select[name='#{name}']", visible: :all)
    wrapper = original.find(:xpath, '..')
    expect(wrapper['data-controller']).to include('delta-select')
    expect(wrapper).to have_css('button[aria-haspopup="listbox"]', visible: true)
    wrapper
  end

  scenario 'converts ordinary product fields without replacing their form controls' do
    visit new_admin_product_path

    wrapper = enhanced_select('product[tracking_mode]')
    wrapper.find('button[aria-haspopup="listbox"]').click

    expect(wrapper).to have_css('button[aria-expanded="true"]')
    expect(wrapper).to have_css('[role="option"][aria-selected="true"]')
    expect(wrapper).to have_css('[role="option"][aria-selected="false"]')
    expect(wrapper).to have_css('select[name="product[tracking_mode]"]', visible: :all)
    wrapper.find('button[aria-haspopup="listbox"]').click
    expect(wrapper).to have_css('button[aria-expanded="false"]')
    wrapper.find('button[aria-haspopup="listbox"]').click
    expect(wrapper).to have_css('button[aria-expanded="true"]')
    find('h1, header', match: :first).click
    expect(wrapper).to have_css('button[aria-expanded="false"]')
  end

  scenario 'preserves account status filtering after a custom dropdown selection' do
    visit admin_supplier_bank_accounts_path(supplier)

    wrapper = enhanced_select('status')
    wrapper.find('button[aria-haspopup="listbox"]').click
    archived = wrapper.find('[role="option"]', text: 'Inactive', exact_text: true)
    archived.click
    expect(find('select[name="status"]', visible: :all).value).to eq('archived')
    click_button 'Search'
    expect(page).to have_current_path(/status=archived/)
  end

  scenario 'upgrades dynamically inserted selects but skips multi-select controls' do
    visit new_admin_supplier_bank_account_path(supplier)
    page.execute_script(<<~JS)
      const added = document.createElement('select')
      added.id = 'added-single-choice'
      added.innerHTML = '<option value="a">Option A</option><option value="b">Option B</option>'
      document.body.append(added)
      const multiple = document.createElement('select')
      multiple.id = 'added-multiple-choice'
      multiple.multiple = true
      multiple.innerHTML = '<option>One</option><option>Two</option>'
      document.body.append(multiple)
    JS

    expect(page).to have_css('#added-single-choice + button[aria-haspopup="listbox"]')
    expect(page).to have_no_css('#added-multiple-choice + button[aria-haspopup="listbox"]')
    find('#added-single-choice', visible: :all).find(:xpath, '..').find('button').click
    find('#added-single-choice', visible: :all).find(:xpath, '..').find('[role="option"]', text: 'Option B').click
    expect(find('#added-single-choice', visible: :all).value).to eq('b')
  end
end
