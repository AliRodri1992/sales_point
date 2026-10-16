# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier dossier navigation and overview', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:, name: 'Verifiable Supplier') }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  def dossier
    Nokogiri::HTML(response.body)
  end

  it 'shows the new responsive navigation with only existing supplier features' do
    get admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(dossier.css('button[data-supplier-dossier-target="tab"]').pluck('data-section')).to eq(
      %w[overview general fiscal commercial contacts addresses schedules documents products finances]
    )
    expect(dossier.at_css('select[data-supplier-dossier-target="mobileSelect"]')).to be_present
    expect(dossier.at_css('#supplier-dossier-overview')).to be_present
    expect(dossier.at_css('#supplier-dossier-overview')['class']).not_to include('hidden')
    expect(dossier.at_css('#supplier-dossier-fiscal')['class']).to include('hidden')
    expect(response.body).not_to include('data-section="reconciliation"')
  end

  it 'separates general company information from fiscal details' do
    get admin_supplier_path(supplier)

    general = dossier.at_css('#supplier-dossier-general')
    fiscal = dossier.at_css('#supplier-dossier-fiscal')
    expect(general.text).to include('Legal name', 'Trade name')
    expect(general.text).not_to include('Tax regime')
    expect(fiscal.text).to include('RFC', 'Tax regime', supplier.rfc)
    expect(fiscal.text).not_to include('Credit limit')
  end

  it 'shows actual registered contact counts in the overview' do
    create(:contact, contactable: supplier, name: 'Operations Contact', primary: true)

    get admin_supplier_path(supplier)

    summary = dossier.at_css('#supplier-dossier-overview')
    expect(summary.text).to include('Operations Contact')
    expect(summary.text).to include('Registered contacts')
  end

  it 'allows direct links to fiscal or contacts sections' do
    get admin_supplier_path(supplier, tab: 'fiscal')
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('fiscal')

    get admin_supplier_path(supplier, tab: 'contacts')
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('contacts')
  end

  it 'falls back to the overview for unknown sections' do
    get admin_supplier_path(supplier, tab: 'reconciliation')
    expect(dossier.at_css('[data-controller="supplier-dossier"]')['data-supplier-dossier-initial-tab-value'])
      .to eq('overview')
  end

  it 'preserves the supplier edit and all existing management links' do
    get admin_supplier_path(supplier)

    expect(response.body).to include(edit_admin_supplier_path(supplier))
    expect(response.body).to include(admin_supplier_contacts_path(supplier))
    expect(response.body).to include(admin_supplier_addresses_path(supplier))
    expect(response.body).to include(admin_supplier_schedules_path(supplier))
    expect(response.body).to include(admin_supplier_supplier_products_path(supplier))
  end
end
