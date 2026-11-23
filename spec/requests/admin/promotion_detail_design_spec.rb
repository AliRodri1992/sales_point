# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Promotion detail design', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:offer) do
    organization.promotions.create!(name: 'Detail campaign', currency: 'MXN', usage_limit: 20,
                                    promotion_benefits_attributes: [{ kind: 'percentage', value: 10 }])
  end

  before do
    create(:organization_membership, user:, organization:)
    create(:currency, code: 'MXN')
    sign_in user
  end

  it 'shows actual benefits and usage, all simulation fields and both empty footer cards' do
    get admin_promotion_path(offer)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('.promotion-detail-offer strong').text).to eq('10%')
    expect(document.at_css('.promotion-detail-usage').text).to include('0 / 20')
    progress = document.at_css('.promotion-detail-usage progress')
    expect([progress['value'], progress['max']]).to eq(%w[0 20])
    expect(document.css('.promotion-detail-footer-grid > section').pluck('aria-labelledby'))
      .to eq(%w[commercial-overlaps-heading campaign-history-title])
    expect(document.at_css('[aria-labelledby="commercial-overlaps-heading"]').text)
      .to include('No other active promotions')
    expect(document.at_css('[aria-labelledby="campaign-history-title"]').text).to include('No activity recorded yet.')
    %w[product quantity segment customer at variant presentation].each do |field|
      expect(document.at_css("#commercial-preview-#{field}")).to be_present
    end
    expect(document.at_css('.promotion-preview-note').text).to include('does not record a sale')
  end

  it 'keeps overlap results tenant-scoped and audit history tied to the selected promotion' do
    local = organization.promotions.create!(name: 'Local overlapping campaign', currency: 'MXN', status: 'active',
                                            promotion_benefits_attributes: [{ kind: 'percentage', value: 5 }])
    Promotion.create!(organization: create(:organization), name: 'Foreign overlap', currency: 'MXN', status: 'active',
                      promotion_benefits_attributes: [{ kind: 'percentage', value: 5 }])
    patch admin_promotion_path(offer), params: { promotion: { name: 'Detail campaign renamed' } }
    expect(response).to have_http_status(:see_other)
    get admin_promotion_path(offer)

    document = Nokogiri::HTML(response.body)
    warning = document.at_css('.promotion-overlap-warning')
    expect(warning.at_css("a[href='#{admin_promotion_path(local)}']").text).to eq('Local overlapping campaign')
    expect(warning.text).not_to include('Foreign overlap')
    expect(document.at_css('.promotion-detail-history').text).to include('Campaign updated')
  end

  it 'shows unlimited usage or a full progress indicator according to recorded redemptions' do
    offer.update!(usage_limit: nil)
    get admin_promotion_path(offer)
    usage = Nokogiri::HTML(response.body).at_css('.promotion-detail-usage')
    expect(usage.at_css('.promotion-detail-usage-meta').text).to eq('No limit')
    expect(usage.at_css('progress')).to be_nil

    offer.update!(usage_limit: 1)
    product = create(:product, organization:, price: 100)
    offer.promotion_redemptions.create!(organization:, product:, quantity: 1, discount: 10, idempotency_key: 'test-use')
    get admin_promotion_path(offer)
    progress = Nokogiri::HTML(response.body).at_css('.promotion-detail-progress.is-full')
    expect([progress['value'], progress['max']]).to eq(%w[1 1])
  end

  it 'does not expose overlaps, history or lifecycle actions without their permissions' do
    reader = create(:user, :english)
    create(:organization_membership, user: reader, organization:)
    role = create(:system_role, :system)
    create(:user_role, user: reader, system_role: role)
    GranularPermissionCatalog.sync!
    %w[promotions.access promotions.show].each do |code|
      create(:system_role_permission, system_role: role, permission: Permission.find_by!(code:))
    end
    sign_in reader
    get admin_promotion_path(offer)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#commercial-preview-product')).to be_present
    expect(document.at_css('.promotion-detail-footer-grid')).to be_nil
    expect(document.at_css('.promotion-lifecycle-action')).to be_nil
    expect(document.at_css("a[href='#{edit_admin_promotion_path(offer)}']")).to be_nil
  end
end
