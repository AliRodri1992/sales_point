# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Promotion campaigns', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user: administrator)
    create(:user_role, user: administrator,
                       system_role: create(:system_role, :system, code: 'administrator'))
    create(:currency, code: 'MXN')
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'recovers selected targets and benefits after validation, then saves a draft' do
    product = create(:product, organization:, name: 'Forest honey')
    create(:category, organization:, name: 'Seasonal groceries')
    visit new_admin_promotion_path

    expect(page).to have_no_field('promotion_code')
    expect(page).to have_field('promotion_display_code', with: 'Generated on save', readonly: true)
    expect(page).to have_no_select('promotion_status', visible: :all)
    click_button 'Add condition'
    within('[data-condition-kind="product"]') do
      find('[data-condition-value="product"] input[type="search"]').set('Forest')
      find('[data-condition-value="product"] ul button', text: 'Forest honey').send_keys(:enter)
    end
    click_button 'Add condition'
    within(all('[data-condition-kind="product"]').last) do
      find('button[aria-haspopup="listbox"]').click
      find('[role="option"]', text: 'Included category').click
      find('[data-condition-value="category"] input[type="search"]').set('Seasonal')
      find('[data-condition-value="category"] ul button', text: 'Seasonal groceries').click
      click_button 'Remove condition'
    end
    within('#campaign-benefits') { fill_in 'Value', with: '15' }
    click_button 'Save draft'

    expect(page).to have_css('#promotion_name[aria-invalid="true"]')
    within('[data-condition-kind="product"]') do
      expect(find('[data-condition-value="product"] input[type="search"]').value).to eq('Forest honey')
    end
    within('#campaign-benefits') { expect(page).to have_field('Value', with: /15/) }
    fill_in 'promotion_name', with: 'Harvest'
    click_button 'Save draft'

    expect(page).to have_css('h1', text: 'Harvest')
    campaign = organization.promotions.find_by!(name: 'Harvest')
    expect(campaign.code).to match(/\APRO-\d{6,}\z/)
    expect(campaign.promotion_conditions.sole.product_id).to eq(product.id)
    expect(campaign.promotion_benefits.sole.value).to eq(15)
    expect(campaign).to be_draft
    click_button 'Activate'
    within('.swal2-popup.delta-confirm-popup') { click_button 'Cancel' }
    expect(campaign.reload).to be_draft
    click_button 'Activate'
    within('.swal2-popup.delta-confirm-popup') { click_button 'Confirm' }
    expect(page).to have_css('.catalog-status', exact_text: 'Active')
    expect(page).to have_text('Campaign activated')
    expect(page).to have_button('Pause')
  end

  scenario 'keeps product search results floating and uses borderless benefit rows on small screens' do
    8.times { |index| create(:product, organization:, name: format('Lookup sample %02d', index)) }
    visit new_admin_promotion_path
    page.current_window.resize_to(390, 900)

    benefit = find('.promotion-benefit-row')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-benefit-row')).borderTopWidth"
    )).to eq('0px')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-benefit-row')).paddingTop"
    )).to eq('0px')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-benefit-row .promotion-editor-remove')).borderTopWidth"
    )).to eq('0px')

    click_button 'Add condition'
    condition = find('.promotion-condition-row')
    initial_height = condition.native.rect.height
    within(condition) { find('input[type="search"]').set('Lookup sample') }
    within(condition) { expect(page).to have_css('ul[role="listbox"]:not([hidden]) button', minimum: 8) }

    measurements = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.promotion-condition-row')
        const list = row.querySelector('[data-promotion-lookup-target="results"]')
        const lookup = row.querySelector('[data-controller="promotion-lookup"]')
        return {
          position: getComputedStyle(list).position,
          height: row.getBoundingClientRect().height,
          dropdownHeight: list.getBoundingClientRect().height,
          dropdownWidth: list.getBoundingClientRect().width,
          fieldWidth: lookup.getBoundingClientRect().width,
          scrollable: list.scrollHeight > list.clientHeight
        }
      })()
    JS
    expect(measurements['position']).to eq('absolute')
    expect(measurements['height']).to be_within(2).of(initial_height)
    expect(measurements['dropdownHeight']).to be <= 208
    expect(measurements['dropdownWidth']).to be_within(2).of(measurements['fieldWidth'])
    expect(measurements['scrollable']).to be(true)
    within(condition) { find('ul[role="listbox"] button', text: 'Lookup sample 00').click }
    expect(condition.find('input[type="search"]').value).to eq('Lookup sample 00')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
  end

  scenario 'filters by a selected product and retains the applied selection on reload' do
    product = create(:product, organization:, name: 'Cedar soap')
    campaign = organization.promotions.create!(name: 'Soap offer', currency: 'MXN')
    campaign.promotion_conditions.create!(kind: :product, product:)
    organization.promotions.create!(name: 'Blanket offer', currency: 'MXN')
    visit admin_promotions_path

    find('summary', text: 'Advanced filters').click
    fill_in 'Search products', with: 'Cedar'
    find('#campaign-product-search-results button', text: 'Cedar soap').click
    click_button 'Search'
    expect(page).to have_current_path(/product_id=#{product.id}/)
    within('#campaign-results') do
      expect(page).to have_link('Soap offer')
      expect(page).to have_no_link('Blanket offer')
    end
    page.refresh
    expect(page).to have_field('Search products', with: 'Cedar soap')
  end

  scenario 'shows advanced filter counts, sorts matching promotions and clears an empty result' do
    organization.promotions.create!(name: 'Zulu offer', currency: 'MXN',
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: 15 }])
    organization.promotions.create!(name: 'Alpha offer', currency: 'MXN',
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
    visit admin_promotions_path(currency: 'MXN', benefit_kind: 'percentage')

    expect(page).to have_css('summary .promotion-advanced-count', exact_text: '2')
    expect(page).to have_css('.promotion-directory-count', exact_text: '2')
    expect(page).to have_css('#campaign-results h2', text: 'Promotion')
    expect(page).to have_css('.promotion-directory-row:first-child', text: 'Alpha offer')
    click_link 'Ascending order'
    expect(page).to have_current_path(/direction=desc/)
    expect(page).to have_css('.promotion-directory-row:first-child', text: 'Zulu offer')
    fill_in 'Find a promotion', with: 'No matching name'
    click_button 'Search'
    expect(page).to have_text('No promotions found')
    expect(page).to have_css('footer.catalog-list-pagination')
    click_link 'Clear filters', exact: true
    expect(page).to have_css('.promotion-directory-count', exact_text: '2')
    expect(page).to have_no_css('.promotion-advanced-count')
  end

  scenario 'opens section help, closes it with Escape and uses the same back button in detail and edit' do
    campaign = organization.promotions.create!(name: 'Readable campaign', currency: 'MXN')
    visit admin_promotion_path(campaign)
    expect(page).to have_link('Back to list', count: 1)
    help = first('button[data-section-help-trigger]')
    help.click
    expect(page).to have_css('[data-section-help-panel]', visible: true)
    help.send_keys(:escape)
    expect(page).to have_no_css('[data-section-help-panel]', visible: true)

    visit edit_admin_promotion_path(campaign)
    expect(page).to have_link('Back', count: 1, href: admin_promotion_path(campaign))
    expect(page).to have_field('promotion_display_currency', with: 'MXN', readonly: true)
    expect(page).to have_button('Save changes')
    expect(page).to have_css('[data-controller="delta-select"] select#promotion_combination_mode', visible: :all)
    expect(page).to have_css('[data-controller="promotion-date"] input#promotion_starts_at', visible: :all)
  end

  scenario 'selects an emerald calendar day without losing the existing time or seconds' do
    visit new_admin_promotion_path
    page.execute_script("document.getElementById('promotion_starts_at').value = '2027-05-08T14:22:37'")
    within('[data-controller="promotion-date"]', match: :first) do
      find('button[data-promotion-date-target="trigger"]').click
      expect(page).to have_css('[data-date="2027-05-08"][aria-pressed="true"]')
      expect(page).to have_css('[data-date="2027-05-08"]:focus')
      find('[data-date="2027-05-09"]').click
      expect(find('#promotion_starts_at', visible: :all).value).to eq('2027-05-09T14:22:37')
      click_button 'Apply'
      find('button[data-promotion-date-target="trigger"]').click
      expect(page).to have_css('[data-date="2027-05-09"][aria-pressed="true"]')
      click_button 'Clear'
      expect(find('#promotion_starts_at', visible: :all).value).to be_blank
    end
  end

  scenario 'shows removable URL filters and fits mobile and desktop widths' do
    organization.promotions.create!(name: 'Autumn', currency: 'MXN')
    organization.promotions.create!(name: 'Spring', currency: 'MXN')
    visit admin_promotions_path(search: 'Autumn', status: 'draft')

    within('#campaign-results') do
      expect(page).to have_link('Autumn')
      expect(page).to have_no_link('Spring')
    end
    [320, 390, 540, 640, 740, 768, 900, 1023, 1099, 1240, 1440].each do |width|
      page.current_window.resize_to(width, 900)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    within('nav[aria-label="Applied filters"]') { find('a', text: 'Autumn').click }
    expect(page).to have_no_current_path(/search=/)
    expect(page).to have_current_path(/status=draft/)
    within('#campaign-results') { expect(page).to have_link('Spring') }
  end

  scenario 'matches v3 title icons, active KPI, mobile header actions, and borderless conditions' do
    campaign = organization.promotions.create!(name: 'Autumn offer', currency: 'MXN')
    visit admin_promotions_path

    expect(page).to have_css('.promotion-metric--active .promotion-metric-icon svg')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-metric--active .promotion-metric-icon')).backgroundColor"
    )).to eq('rgb(236, 253, 245)')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-module-icon')).backgroundColor"
    )).to eq('rgb(209, 250, 229)')

    visit admin_promotion_path(campaign)
    page.current_window.resize_to(390, 900)
    expect(page).to have_css('.promotion-heading-actions .catalog-button', count: 2)
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-heading-actions')).justifyContent"
    )).to eq('flex-start')
    expect(page.evaluate_script(
      "Math.round(document.querySelector('.promotion-module-icon').getBoundingClientRect().width)"
    )).to eq(43)

    visit edit_admin_promotion_path(campaign)
    click_button 'Add condition'
    expect(page).to have_css('.promotion-condition-row')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-condition-row')).borderTopWidth"
    )).to eq('0px')
    expect(page.evaluate_script(
      "getComputedStyle(document.querySelector('.promotion-heading-actions')).justifyContent"
    )).to eq('flex-start')
  end

  scenario 'uses the catalog pagination controls for both commercial directories' do
    %i[promotions price_lists].each do |resource|
      12.times do |index|
        organization.public_send(resource).create!(name: format('Demo %02d', index + 1), currency: 'MXN')
      end
      visit public_send("admin_#{resource}_path", search: 'Demo', per_page: 10)
      page.current_window.resize_to(390, 900)
      expect(page).to have_css('footer.catalog-list-pagination [aria-current="page"]', exact_text: '1')
      expect(page).to have_link('Demo 10')
      expect(page).to have_no_link('Demo 11')
      within('.catalog-list-pagination-links') { click_link '2', exact: true }
      expect(page).to have_link('Demo 12')
      expect(page).to have_no_link('Demo 01')
      wrapper = find("##{resource}_per_page", visible: :all).find(:xpath, '..')
      wrapper.find('button[aria-haspopup="listbox"]').click
      wrapper.find('[role="option"]', text: '5', exact_text: true).click
      expect(page).to have_current_path(/per_page=5/)
      expect(page).to have_link('Demo 05')
      expect(page).to have_no_link('Demo 06')
      expect(page.current_url).to include('search=Demo')
      expect(page).to have_css('.catalog-list-pagination [aria-current="page"]', exact_text: '1')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    end
  end
end
