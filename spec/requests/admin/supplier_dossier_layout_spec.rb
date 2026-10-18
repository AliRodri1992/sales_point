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

  it 'renders the illustrated document empty state with an upload entry point' do
    get admin_supplier_path(supplier, tab: 'documents')

    panel = dossier.at_css('section[data-section="documents"]')
    expect(panel.at_css('img[src*="sdocuments"]')).to be_present
    expect(panel.text).to include('No documents registered yet')
    expect(panel.at_css("a[href='#{edit_admin_supplier_path(supplier)}']")).to be_present
  end

  it 'hides the document empty state when attachments exist' do
    supplier.documents.attach(
      io: StringIO.new('%PDF-1.4 test document'),
      filename: 'invoice.pdf',
      content_type: 'application/pdf'
    )

    get admin_supplier_path(supplier, tab: 'documents')

    panel = dossier.at_css('section[data-section="documents"]')
    expect(panel.text).to include('invoice.pdf')
    expect(panel.at_css('img[src*="sdocuments"]')).to be_nil
  end

  it 'does not offer document upload without document management permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_documents?).and_return(false)

    get admin_supplier_path(supplier, tab: 'documents')

    panel = dossier.at_css('section[data-section="documents"]')
    expect(panel.at_css('img[src*="sdocuments"]')).to be_present
    expect(panel.at_css("a[href='#{edit_admin_supplier_path(supplier)}']")).to be_nil
  end

  it 'separates the calendar empty state from its management header' do
    get admin_supplier_path(supplier, tab: 'schedules')

    panel = dossier.at_css('section[data-section="schedules"]')
    header = panel.at_xpath('./div[1]')
    empty_state = panel.at_css('img[src*="scalendaries"]').parent

    expect(header.text).to include('Manage calendars')
    expect(header.at_css("a[href='#{admin_supplier_schedules_path(supplier)}']")).to be_present
    expect(header.text).not_to include('No calendars registered yet')
    expect(empty_state.text).to include('No calendars registered yet')
    expect(panel.css("a[href='#{admin_supplier_schedules_path(supplier)}']").size).to eq(1)
  end

  it 'shows a compact fiscal address empty state without an add button' do
    get admin_supplier_path(supplier, tab: 'fiscal')

    section = dossier.at_css('[data-fiscal-address]')
    expect(section.at_css('img[src*="staxaddress"]')).to be_present
    expect(section.text).to include('No fiscal address registered yet')
    expect(section.css('a, button').map(&:text).join).not_to include('Add fiscal address')
  end

  it 'shows registered fiscal address fields instead of the empty illustration' do
    supplier.addresses.create!(
      street: 'Main Street', exterior_number: '10', neighborhood: 'Centro',
      city: 'CDMX', state: 'CDMX', postal_code: '06000',
      country: create(:country), purpose: 'fiscal'
    )

    get admin_supplier_path(supplier, tab: 'fiscal')

    section = dossier.at_css('[data-fiscal-address]')
    expect(section.text).to include('Main Street')
    expect(section.at_css('img[src*="staxaddress"]')).to be_nil
  end

  it 'keeps supplier address summary aligned with the left card edge' do
    supplier.addresses.create!(
      street: 'Main Street', exterior_number: '23', neighborhood: 'Centro',
      city: 'Ixtepec', state: 'Oaxaca', postal_code: '70111',
      country: create(:country), purpose: 'delivery'
    )

    get admin_supplier_path(supplier, tab: 'addresses')

    card = dossier.at_css('[data-supplier-address-id]')
    summary = card.css('div').find { |node| node['class']&.include?('mt-4 flex items-start gap-2') }
    expect(summary).to be_present
    expect(summary['class']).not_to include('pl-14')
    expect(summary.text).to include('Main Street 23', 'Ixtepec', 'Oaxaca')
  end

  it 'renders the empty products illustration and actions for administrators' do
    get admin_supplier_path(supplier, tab: 'products')

    panel = dossier.at_css('section[data-section="products"]')
    expect(panel.at_css('img[src*="sproducts"]')).to be_present
    expect(panel.text).to include('No products registered yet')
    expect(panel.at_css("a[href='#{admin_supplier_supplier_products_path(supplier)}']")).to be_present
    expect(panel.at_css("a[href='#{new_admin_supplier_supplier_product_path(supplier)}']")).to be_present
  end

  it 'does not show product creation without management permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:manage_products?).and_return(false)

    get admin_supplier_path(supplier, tab: 'products')

    panel = dossier.at_css('section[data-section="products"]')
    expect(panel.at_css('img[src*="sproducts"]')).to be_present
    expect(panel.at_css("a[href='#{new_admin_supplier_supplier_product_path(supplier)}']")).to be_nil
  end

  it 'shows the new responsive navigation with only existing supplier features' do
    get admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(dossier.css('button[data-supplier-dossier-target="tab"]').pluck('data-section')).to eq(
      %w[overview general fiscal commercial contacts addresses schedules documents products bank_accounts statement]
    )
    expect(dossier.at_css('select[data-supplier-dossier-target="mobileSelect"]')).to be_present
    expect(dossier.at_css('#supplier-dossier-overview')).to be_present
    expect(dossier.at_css('#supplier-dossier-overview')['class']).not_to include('hidden')
    expect(dossier.at_css('#supplier-dossier-fiscal')['class']).to include('hidden')
    expect(response.body).not_to include('data-section="reconciliation"')
  end

  it 'places Back outside the three-dot menu and Edit inside it' do
    get admin_supplier_path(supplier)

    header = dossier.at_css('[data-controller="supplier-dossier"] > header')
    back_link = header.at_css("a[href='#{admin_suppliers_path}']")
    edit_link = header.at_css("details a[href='#{edit_admin_supplier_path(supplier)}']")

    expect(back_link).to be_present
    expect(back_link.text).to include('Back')
    expect(back_link.ancestors('details')).to be_empty
    expect(edit_link).to be_present
    expect(edit_link.text).to include('Edit')
    expect(header.css("a[href='#{edit_admin_supplier_path(supplier)}']").size).to eq(1)
    expect(header.at_css('details summary[aria-label]')).to be_present
  end

  it 'keeps Back available and hides the edit menu without update permission' do
    allow_any_instance_of(SupplierPolicy).to receive(:update?).and_return(false)

    get admin_supplier_path(supplier)

    header = dossier.at_css('[data-controller="supplier-dossier"] > header')
    expect(header.at_css("a[href='#{admin_suppliers_path}']")).to be_present
    expect(header.at_css('details')).to be_nil
    expect(header.at_css("a[href='#{edit_admin_supplier_path(supplier)}']")).to be_nil
  end

  it 'uses the entire right-side area for every supplier section' do
    get admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    layout = dossier.at_css('[data-supplier-dossier-content]')
    expect(layout).to be_present
    expect(layout['class']).to include('w-full', 'flex-col')
    expect(dossier.at_css('[data-supplier-dossier-content]').parent['class'])
      .to include('lg:grid', 'lg:items-stretch')

    sections = %w[
      overview general fiscal commercial contacts addresses schedules documents products bank_accounts statement
    ]
    expect(layout.css('[data-supplier-dossier-target="panel"]').pluck('data-section')).to match_array(sections)
    layout.css('[data-supplier-dossier-target="panel"]').each do |panel|
      expect(panel['class']).to include('w-full', 'min-w-0', 'lg:flex-1')
    end
  end

  it 'highlights the full width of the selected menu item, not only its label' do
    get admin_supplier_path(supplier)

    sidebar = dossier.at_css('aside[aria-label] nav')
    expect(sidebar['class']).to include('lg:-mx-3')
    sidebar.css('button[data-supplier-dossier-target="tab"]').each do |tab|
      expect(tab['class']).to include('w-full', 'lg:px-6')
    end
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
