# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchase and supplier breadcrumbs', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def current_crumb
    Nokogiri::HTML(response.body).at_css('nav[aria-label] [aria-current="page"]')&.text&.strip
  end

  def previous_crumb
    Nokogiri::HTML(response.body).css('nav[aria-label] ol li a').last&.text&.strip
  end

  %i[es en ko].each do |locale|
    it "translates purchasing module breadcrumb labels in #{locale}" do
      language = Language.find_by(code: locale) || create(:language, code: locale, name: locale, flag_iso: 'mx')
      user.update!(language:)

      {
        admin_purchase_orders_path => 'orders',
        admin_purchase_requests_path => 'requests',
        admin_purchase_quotations_path => 'quotations',
        admin_purchase_returns_path => 'returns'
      }.each do |path, key|
        get path

        expect(response).to have_http_status(:ok)
        expect(current_crumb).to eq(I18n.t("admin.purchases.#{key}", locale:))
      end
    end
  end

  it 'uses translated breadcrumb labels when creating and viewing a purchase request' do
    branch = create(:branch, organization:)
    request = PurchaseRequest.create!(organization:, branch:, requested_by: user)

    get new_admin_purchase_request_path
    expect(response).to have_http_status(:ok)
    expect(previous_crumb).to eq(I18n.t('admin.purchases.requests', locale: :en))
    expect(current_crumb).to eq(I18n.t('admin.purchases.new_request', locale: :en))

    get admin_purchase_request_path(request)
    expect(response).to have_http_status(:ok)
    expect(previous_crumb).to eq(I18n.t('admin.purchases.requests', locale: :en))
    expect(current_crumb).to eq(request.code)
  end

  it 'translates supplier product and bank account breadcrumbs' do
    get admin_supplier_supplier_products_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(current_crumb).to eq(I18n.t('admin.procurement.title', locale: :en))

    get admin_supplier_bank_accounts_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(current_crumb).to eq(I18n.t('admin.accounts_payable.bank_accounts', locale: :en))
  end

  it 'keeps translated supplier contact and address breadcrumb labels' do
    get admin_supplier_contacts_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(current_crumb).to eq(I18n.t('admin.supplier_details.contacts', locale: :en))

    get admin_supplier_addresses_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(current_crumb).to eq(I18n.t('admin.supplier_details.addresses', locale: :en))
  end
end
