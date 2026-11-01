# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Financial breadcrumbs', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def breadcrumb_current_label
    Nokogiri::HTML(response.body).at_css('nav[aria-label] [aria-current="page"]')&.text&.strip
  end

  def breadcrumb_parent_label
    Nokogiri::HTML(response.body).css('nav[aria-label] ol li a').last&.text&.strip
  end

  %w[es en ko].each do |locale|
    it "shows financial module names in #{locale}" do
      language = Language.find_by(code: locale) ||
                 create(:language, code: locale, name: locale, flag_iso: 'mx')
      user.update!(language:)

      {
        admin_account_payables_path => 'payables',
        admin_supplier_invoices_path => 'invoices',
        admin_supplier_payments_path => 'payments',
        admin_supplier_credit_notes_path => 'credits'
      }.each do |url, key|
        get url

        expect(response).to have_http_status(:ok)
        expect(breadcrumb_current_label).to eq(
          I18n.t("admin.accounts_payable.breadcrumbs.#{key}", locale:)
        )
      end
    end
  end

  it 'keeps the breadcrumb landmark separate from the labeled sidebar navigation' do
    get admin_supplier_invoices_path

    document = Nokogiri::HTML(response.body)
    labels = document.css('nav[aria-label]').pluck('aria-label')
    expect(labels).to include(I18n.t('admin.breadcrumbs.label', locale: :en))
    expect(labels).not_to include(I18n.t('admin.shared.sidebar.navigation', locale: :en))
    expect(document.at_css('#adminSidebar nav')['aria-labelledby']).to eq('adminSidebarNavigationLabel')
  end

  it 'uses localized parent and action labels on the supplier invoice form' do
    get new_admin_supplier_invoice_path

    expect(response).to have_http_status(:ok)
    expect(breadcrumb_parent_label).to eq(I18n.t('admin.accounts_payable.breadcrumbs.invoices', locale: :en))
    expect(breadcrumb_current_label).to eq(I18n.t('admin.accounts_payable.new_invoice', locale: :en))
  end

  it 'shows the invoice folio beneath the localized financial section' do
    supplier = create(:supplier, organization:)
    invoice = SupplierInvoice.create!(
      organization:, supplier:, currency: supplier.currency, created_by: user,
      issued_on: Date.current, received_on: Date.current,
      due_on: Date.tomorrow, subtotal: 100, total: 100, folio: 'FAC-2026'
    )

    get admin_supplier_invoice_path(invoice)

    expect(response).to have_http_status(:ok)
    expect(breadcrumb_parent_label).to eq(I18n.t('admin.accounts_payable.breadcrumbs.invoices', locale: :en))
    expect(breadcrumb_current_label).to eq('FAC-2026')
  end
end
