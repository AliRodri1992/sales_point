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
    find_button(/Forest honey/).send_keys(:enter)
    fill_in 'Search categories', with: 'Seasonal'
    click_button(/Seasonal groceries/)
    within('[data-condition-kind="category"]') { click_button(/Remove/) }
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
    click_button(/Cedar soap/)
    click_button 'Apply filters'
    expect(page).to have_current_path(/product_id=#{product.id}/)
    within('#campaign-results') do
      expect(page).to have_link('Soap offer')
      expect(page).to have_no_link('Blanket offer')
    end
    page.refresh
    expect(page).to have_field('Search products', with: 'Cedar soap')
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

    within('nav[aria-label="Applied filters"]') { click_link(/Autumn/) }
    expect(page).to have_no_current_path(/search=/)
    expect(page).to have_current_path(/status=draft/)
    within('#campaign-results') { expect(page).to have_link('Spring') }
  end
end
