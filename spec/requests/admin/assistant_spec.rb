# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deltín assistant', type: :request do
  let(:organization) { create(:organization, :with_settings) }
  let(:user) { create(:user, :spanish) }

  before do
    create(:organization_membership, organization:, user:)
    sign_in user
  end

  it 'uses the approved two-ear mascot assets in the admin layout' do
    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('[data-controller="deltin-assistant"]')).to be_present
    expect(page.at_css('#deltin-panel[role="dialog"]')).to be_present
    avatar = page.at_css('img.deltin-avatar')
    portrait = page.at_css('img.deltin-portrait')
    expect(avatar['src']).to include('deltin/portrait')
    expect(portrait['src']).to include('deltin/waving')
    expect(portrait['alt']).to eq(I18n.t('admin.assistant.mascot_alt'))
    expect(page.at_css('svg.deltin-character')).to be_nil
    expect(Rails.root.join('app/assets/images/deltin/portrait.webp')).to exist
    expect(Rails.root.join('app/assets/images/deltin/waving.webp')).to exist
    expect(page.at_css('#chatFloatingButton')).to be_nil
  end

  it 'answers product questions from the guide without exposing data' do
    post admin_assistant_reply_path, params: {
      message: 'Dar de alta un producto', context: 'products'
    }, as: :json

    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data['source']).to eq('guide')
    expect(data['title']).to eq('Dar de alta un producto')
    expect(data.fetch('steps')).not_to be_empty
    expect(data['guide_url']).to eq('/admin/guide#guide-products')
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'does not expose finance procedures without permission' do
    post admin_assistant_reply_path, params: {
      message: 'Contabilizar pago', context: 'supplier_payments'
    }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['steps']).to be_empty
    expect(response.parsed_body['guide_url']).to eq('/admin/guide')
  end

  it 'explains validation errors without inventing an operation' do
    post admin_assistant_reply_path, params: {
      message: 'Corregir un error de validación', context: 'products'
    }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['mood']).to eq('concerned')
    expect(response.parsed_body['source']).to eq('help')
    expect(response.parsed_body.fetch('steps').length).to eq(4)
  end

  it 'rejects empty and oversized messages' do
    ['', 'x' * 501].each do |message|
      post admin_assistant_reply_path, params: { message: }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it 'requires an authenticated session' do
    sign_out user

    post admin_assistant_reply_path, params: { message: 'Crear producto' }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not return procedures without an active organization membership' do
    user.organization_memberships.find_by!(organization:).update!(status: :inactive)

    post admin_assistant_reply_path, params: { message: 'Dar de alta un producto' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['steps']).to be_empty
  end
end
