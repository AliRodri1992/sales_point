# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Commercial price preview', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english) }
  let(:product) { create(:product, organization:, name: 'Preview tea', price: 100, cost: 20) }

  before do
    create(:organization_membership, organization:, user: administrator)
    create(:user_role, user: administrator, system_role: create(:system_role, :system, code: 'administrator'))
    create(:currency, code: 'MXN')
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'previews a draft price list at a chosen quantity without changing stored prices' do
    list = organization.price_lists.create!(name: 'Test list', code: 'TEST-LIST', currency: 'MXN')
    list.price_list_items.create!(organization:, product:, price: 80)

    visit admin_price_list_path(list)
    within('[data-controller="commercial-preview"]') do
      fill_in 'commercial-preview-product', with: 'Preview tea'
      click_button 'Preview tea', exact: false
      fill_in 'commercial-preview-quantity', with: '2'
      click_button 'Calculate preview'
      expect(page).to have_text(/160(?:\.0+)? MXN/)
    end

    expect(list.reload).to be_draft
    expect(list.price_list_items.sole.price).to eq(80)
    expect(PromotionRedemption.count).to eq(0)
  end

  scenario 'previews a draft promotion without redeeming it' do
    offer = organization.promotions.create!(name: 'Preview campaign', code: 'TEST-PROMO', currency: 'MXN',
                                            promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
    product
    visit admin_promotion_path(offer)
    within('[data-controller="commercial-preview"]') do
      fill_in 'commercial-preview-product', with: 'Preview tea'
      click_button 'Preview tea', exact: false
      click_button 'Calculate preview'
      expect(page).to have_text(/90(?:\.0+)? MXN/)
    end

    expect(offer.reload).to be_draft
    expect(offer.promotion_redemptions).to be_empty
  end
end
