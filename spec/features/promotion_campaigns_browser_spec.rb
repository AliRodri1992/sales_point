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
    expect(page).to have_no_select('promotion_status', visible: :all)
    fill_in 'Search products', with: 'Forest'
    find('#campaign-product-search-results button', text: 'Forest honey').send_keys(:enter)
    fill_in 'Search categories', with: 'Seasonal'
    find('#campaign-category-search-results button', text: 'Seasonal groceries').click
    within('[data-condition-kind="category"]') { click_button 'Remove row' }
    click_button 'Add benefit'
    within('#campaign-benefits') { fill_in 'Value', with: '15' }
    click_button 'Save campaign'

    expect(page).to have_css('#promotion_name[aria-invalid="true"]')
    expect(page).to have_css('[data-condition-kind="product"]', text: 'Forest honey')
    within('#campaign-benefits') { expect(page).to have_field('Value', with: /15/) }
    fill_in 'promotion_name', with: 'Harvest'
    click_button 'Save campaign'

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

  scenario 'filters by a selected product and retains the applied selection on reload' do
    product = create(:product, organization:, name: 'Cedar soap')
    campaign = organization.promotions.create!(name: 'Soap offer', currency: 'MXN')
    campaign.promotion_conditions.create!(kind: :product, product:)
    organization.promotions.create!(name: 'Blanket offer', currency: 'MXN')
    visit admin_promotions_path

    find('summary', text: 'Advanced filters').click
    fill_in 'Search products', with: 'Cedar'
    find('#campaign-product-search-results button', text: 'Cedar soap').click
    click_button 'Apply filters'
    expect(page).to have_current_path(/product_id=#{product.id}/)
    within('#campaign-results') do
      expect(page).to have_link('Soap offer')
      expect(page).to have_no_link('Blanket offer')
    end
    page.refresh
    expect(page).to have_field('Search products', with: 'Cedar soap')
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
    expect(page).to have_link('Back to list', count: 1)
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
      expect(find('#promotion_starts_at').value).to eq('2027-05-09T14:22:37')
      find('button[data-promotion-date-target="trigger"]').click
      expect(page).to have_css('[data-date="2027-05-09"][aria-pressed="true"]')
      click_button 'Clear'
      expect(find('#promotion_starts_at').value).to be_blank
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
    [320, 390, 768, 1440].each do |width|
      page.current_window.resize_to(width, 900)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end

    within('nav[aria-label="Applied filters"]') { find('a', text: 'Autumn').click }
    expect(page).to have_no_current_path(/search=/)
    expect(page).to have_current_path(/status=draft/)
    within('#campaign-results') { expect(page).to have_link('Spring') }
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
