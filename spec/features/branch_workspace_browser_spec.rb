# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branch workspace interactions', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }
  let!(:central) do
    create(:branch, organization:, name: 'Central active', code: 'CENTRAL', contact_email: 'central@example.com')
  end
  let!(:inactive) { create(:branch, organization:, name: 'Central inactive', status: false, code: 'INACTIVE') }
  let!(:north) { create(:branch, organization:, name: 'North office', code: 'NORTH') }

  before do
    create(:organization_membership, user: administrator, organization:)
    create(:user_role, user: administrator, system_role: create(:system_role, :system, code: 'administrator'))
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  def branch_browser_state
    { url: page.current_url,
      values: page.evaluate_script('Array.from(new FormData(document.querySelector(".branch-filters")))'),
      logs: page.driver.browser.logs.get(:browser).map(&:message) }.inspect
  end

  def choose_branch_filter(id, label)
    find("##{id}", visible: :all).find(:xpath, '..').find('button[aria-haspopup="listbox"]').click
    find('[role="option"]', text: label, exact_text: true, visible: true).click
  end

  scenario 'filters while typing, retains focus and removes individual badges without a full navigation' do
    visit admin_branches_path
    page.execute_script('window.branchNavigationMarker = "retained"')
    fill_in 'branch-search', with: 'Central'
    expect(page).to have_css('#branch-filter-badges [data-filter-key="search"]')
    within('#branches_list') do
      expect(page).to have_link(central.name, exact: true)
      expect(page).to have_link(inactive.name, exact: true)
      expect(page).to have_no_link(north.name, exact: true)
    end
    expect(page).to have_css('#branch-search:focus')
    choose_branch_filter('branch-filter-status', 'Suspended')
    within('#branches_list') do
      expect(page).to have_link(inactive.name, exact: true)
      expect(page).to have_no_link(central.name, exact: true), -> { branch_browser_state }
    end
    find('#branch-filter-badges [data-filter-key="status"]').click
    expect(page).to have_no_css('#branch-filter-badges [data-filter-key="status"]')
    expect(page).to have_css('#branch-filter-badges [data-filter-key="search"]')
    expect(page).to have_field('branch-search', with: 'Central')
    expect(page).to have_css('#branch-search:focus')
    expect(page.evaluate_script('window.branchNavigationMarker')).to eq('retained')
    find('#branch-filter-badges [data-filter-key="search"]').click
    within('#branches_list') { expect(page).to have_link(north.name, exact: true) }
    expect(page).to have_no_css('#branch-filter-badges [data-filter-key]')
  end

  scenario 'keeps search and pagination context when navigating into a branch and returning' do
    9.times { |n| create(:branch, organization:, name: "Office #{n}") }
    visit admin_branches_path(search: 'Office', per_page: 5)
    within('.branch-pagination') { click_link '2', exact: true }
    expect(page).to have_current_path(admin_branches_path(search: 'Office', per_page: '5', page: '2'),
                                      ignore_query: false)
    expect(page).to have_field('branch-search', with: 'Office')
    within('#branches_list') { click_link 'Office 5', exact: true }
    expect(page).to have_css('h1', text: 'Office 5')
    click_link I18n.t('admin.branches.form.buttons.back', locale: :en), match: :first
    expect(page).to have_field('branch-search', with: 'Office')
    expect(page).to have_css('[aria-current="page"]', text: '2')
  end

  scenario 'retains results during a network error and allows retrying the same search' do
    visit admin_branches_path
    page.execute_script(<<~JS)
      window.originalBranchFetch = window.fetch.bind(window)
      window.fetch = (input, options) => {
        const url = new URL(String(input), window.location.origin)
        if (url.pathname === '/admin/branches' && options?.headers?.Accept?.includes('turbo-stream')) return Promise.reject(new TypeError('Offline'))
        return window.originalBranchFetch(input, options)
      }
    JS
    fill_in 'branch-search', with: 'North'
    expect(page).to have_css('[data-branch-directory-target="error"]', visible: true)
    within('#branches_list') { expect(page).to have_link(central.name, exact: true) }
    page.execute_script('window.fetch = window.originalBranchFetch')
    find('[data-branch-directory-target="error"] button').click
    within('#branches_list') do
      expect(page).to have_link(north.name, exact: true)
      expect(page).to have_no_link(central.name, exact: true), -> { branch_browser_state }
    end
    expect(page).to have_no_css('[data-branch-directory-target="error"]', visible: true)
  end

  scenario 'renders advanced filters and branch forms without mobile overflow and preserves validation values' do
    page.current_window.resize_to(390, 844)
    visit admin_branches_path
    find('.branch-advanced summary').click
    choose_branch_filter('branch-filter-contact', 'Without email')
    expect(page).to have_css('#branch-filter-badges [data-filter-key="contact"]'), -> { branch_browser_state }
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    [new_admin_branch_path, edit_admin_branch_path(central), admin_branch_path(central)].each do |path|
      visit path
      expect(page).to have_css('main h1', count: 1)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
    visit edit_admin_branch_path(central)
    expect(find('#branch_code')['readonly']).to be_present
    fill_in 'branch_contact_email', with: 'not-an-email'
    click_button I18n.t('admin.branches.form.buttons.update', locale: :en)
    expect(page).to have_css('[role="alert"]')
    expect(page).to have_field('branch_contact_email', with: 'not-an-email')
    page.current_window.resize_to(1440, 1000)
    visit new_admin_branch_path
  end

  scenario 'creates a branch with operational contact details and country-specific required fields' do
    visit new_admin_branch_path
    fill_in 'branch_name', with: 'Airport office'
    expect(find('#branch_code')['readonly']).to be_present
    fill_in 'branch_contact_email', with: 'airport@example.com'
    fill_in 'branch_notes', with: 'Deliveries at gate two.'
    within('[data-country-flags]') { find('button[aria-haspopup="listbox"]').click }
    find('[role="option"]', text: central.address.country.localized_name, exact_text: true, visible: true).click
    expect(page).to have_css('#branch_address_attributes_exterior_number[aria-required="true"]')
    expect(page).to have_no_css('#branch_address_attributes_exterior_number[required]')
    expect(page).to have_css('form[novalidate]')
    expect(page).to have_css('label[for="branch_name"] .branch-required-mark')
    expect(page).to have_css('[data-country-flags] button[aria-required="true"]')
    fill_in 'branch_address_attributes_street', with: 'Airport avenue'
    fill_in 'branch_address_attributes_exterior_number', with: '20'
    fill_in 'branch_address_attributes_neighborhood', with: 'Centro'
    fill_in 'branch_address_attributes_city', with: 'Ciudad de México'
    fill_in 'branch_address_attributes_state', with: 'CDMX'
    fill_in 'branch_address_attributes_postal_code', with: '01000'
    click_button I18n.t('admin.branches.form.buttons.create', locale: :en)
    expect(page).to have_current_path(admin_branches_path, ignore_query: true)
    record = organization.branches.find_by!(name: 'Airport office')
    expect(record.code).to match(/\ABR-[0-9A-F]{12}\z/)
    expect(record).to have_attributes(contact_email: 'airport@example.com', notes: 'Deliveries at gate two.',
                                      operational_status: 'preparing')
  end

  scenario 'resets dependent location filters when removing a country badge' do
    country = create(:country, name: 'United States', iso_alpha2: 'US', iso_alpha3: 'USA', iso_numeric: '840')
    office = create(:branch, organization:, name: 'Austin office')
    office.address.update!(country:, city: 'Austin', state: 'Texas', postal_code: '78701')
    visit admin_branches_path
    find('.branch-advanced summary').click
    choose_branch_filter('branch-filter-country', country.localized_name)
    expect(page).to have_css('#branch-filter-badges [data-filter-key="country_id"]')
    expect(page.evaluate_script('Array.from(document.querySelector("#branch-filter-state").options).map(o => o.value)'))
      .to contain_exactly('', 'Texas')
    choose_branch_filter('branch-filter-state', 'Texas')
    expect(page).to have_css('#branch-filter-badges [data-filter-key="state"]')
    choose_branch_filter('branch-filter-city', 'Austin')
    expect(page).to have_css('#branch-filter-badges [data-filter-key="city"]')
    find('#branch-filter-badges [data-filter-key="country_id"]').click
    expect(page).to have_no_css('#branch-filter-badges [data-filter-key="country_id"]')
    expect(page).to have_no_css('#branch-filter-badges [data-filter-key="state"]')
    expect(page).to have_no_css('#branch-filter-badges [data-filter-key="city"]')
    within('#branches_list') { expect(page).to have_link(office.name, exact: true) }
  end

  scenario 'shows branch details without mobile overflow and keeps section navigation usable' do
    page.current_window.resize_to(390, 844)
    visit admin_branch_path(central, search: 'Central', per_page: 5)

    expect(page).to have_css('.branch-detail-header h1', text: central.name)
    expect(page).to have_css('.branch-detail-nav a[href="#branch-detail-lifecycle"]')
    expect(page).to have_css('.branch-detail-nav a[href="#branch-detail-location"]')
    expect(page).to have_css('#branch-detail-location .branch-detail-address-summary')
    expect(page).to have_css('#branch-detail-operations')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    within('.branch-detail-nav') { click_link I18n.t('admin.branch_workspace.notes', locale: :en) }
    expect(page).to have_current_path(admin_branch_path(central, search: 'Central', per_page: '5') +
                                      '#branch-detail-notes', ignore_query: false)
    expect(page).to have_css('#branch-detail-notes')

    within('.branch-detail-actions') { click_link I18n.t('admin.branches.form.buttons.back', locale: :en) }
    expect(page).to have_field('branch-search', with: 'Central')
  end
end
