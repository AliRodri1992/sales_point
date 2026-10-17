# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier contact cards and progressive loading', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def cards
    Nokogiri::HTML(response.body).css('article[data-supplier-contact-id]')
  end

  it 'separates the contact cards from the title and filter area' do
    create(:contact, contactable: supplier, name: 'Card outside header')

    get admin_supplier_path(supplier, tab: 'contacts')

    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-contacts')
    header = panel.at_css('[data-supplier-contacts-header]')
    list_area = panel.at_css('[data-supplier-contacts-cards]')

    expect(panel['class']).not_to include('bg-white')
    expect(header.parent).to eq(panel)
    expect(list_area.parent).to eq(panel)
    expect(header['class']).to include('bg-white', 'rounded-2xl')
    expect(header.text).to include('Supplier contact people', 'Manage contacts')
    expect(header.css('article[data-supplier-contact-id]')).to be_empty
    expect(list_area.css('article[data-supplier-contact-id]').size).to eq(1)
    expect(list_area.at_css('[data-supplier-contacts-target="list"]')['class']).to include('md:grid-cols-2')
    expect(list_area.at_css('[data-supplier-contacts-target="scroll"]')['class']).to include('overflow-y-auto')
  end

  it 'renders compact contact cards in two columns with hidden expandable details' do
    attributes = {
      name: 'Laura Gómez', position: 'Purchasing',
      notes: 'Call before delivery', email: 'laura@domain.example', primary: true
    }
    contact = create(:contact, contactable: supplier, **attributes)

    get admin_supplier_path(supplier, tab: 'contacts')

    expect(response).to have_http_status(:ok)
    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-contacts')
    expect(panel['data-controller']).to eq('supplier-contacts')
    expect(panel.at_css('[data-supplier-contacts-target="list"]')['class']).to include('md:grid-cols-2')
    expect(panel.at_css('[data-supplier-contacts-target="scroll"]')['class']).to include('overflow-y-auto')
    expect(panel.at_css('[data-supplier-contacts-target="sentinel"]')).to be_present

    card = panel.at_css("article[data-supplier-contact-id='#{contact.id}']")
    expect(card).to be_present
    expect(card.text).to include('Laura Gómez', 'Purchasing', 'laura@domain.example')
    expect(card.at_css('button[aria-expanded="false"]')).to be_present
    expect(card.at_css("[id='supplier-contact-detail-#{contact.id}']")['class']).to include('hidden')
    expect(card.text).to include('Call before delivery')
    expect(card.at_css("a[href='#{edit_admin_supplier_contact_path(supplier, contact)}']")).to be_present
  end

  it 'shows both missing-contact labels when neither phone nor email is registered' do
    contact = create(:contact, contactable: supplier, name: 'No Communication',
                               phone: nil, mobile_phone: nil, email: nil)

    get admin_supplier_path(supplier, tab: 'contacts')

    card = cards.find { |item| item['data-supplier-contact-id'] == contact.id.to_s }
    expect(card.text).to include('Phone not registered', 'Email not registered')
    expect(card.css('a[href^="tel:"], a[href^="mailto:"]')).to be_empty

    get contacts_page_admin_supplier_path(supplier)
    expect(cards.first.text).to include('Phone not registered', 'Email not registered')
  end

  it 'shows a registered mobile number instead of the missing-phone label' do
    create(:contact, contactable: supplier, name: 'Mobile Only',
                     phone: nil, mobile_phone: '5512345678', email: nil)

    get admin_supplier_path(supplier, tab: 'contacts')

    expect(cards.first.css('a[href^="tel:"]').length).to eq(1)
    expect(cards.first.text).not_to include('Phone not registered')
    expect(cards.first.text).to include('Email not registered')
  end

  it 'shows the missing-phone label but preserves the mail link if an email exists' do
    create(:contact, contactable: supplier, name: 'Email Only',
                     phone: nil, mobile_phone: nil, email: 'only@example.com')

    get admin_supplier_path(supplier, tab: 'contacts')

    expect(cards.first.text).to include('Phone not registered')
    expect(cards.first.text).not_to include('Email not registered')
    expect(cards.first.css('a[href^="mailto:"]').length).to eq(1)
  end

  it 'translates the missing communication labels into Spanish and Korean' do
    {
      es: ['Teléfono no registrado', 'Correo electrónico no registrado'],
      ko: ['등록된 전화번호 없음', '등록된 이메일 없음']
    }.each do |locale, labels|
      language = Language.find_by(code: locale.to_s) ||
                 create(:language, code: locale.to_s, name: locale.to_s, flag_iso: 'mx')
      user.update!(language:)
      create(:contact, contactable: supplier, phone: nil, mobile_phone: nil, email: nil) if locale == :es

      get admin_supplier_path(supplier, tab: 'contacts')

      expect(cards.first.text).to include(*labels)
    end
  end

  it 'renders only the first eight contacts and exposes the next page' do
    19.times { |index| create(:contact, contactable: supplier, name: format('Vendor Contact %02d', index)) }

    get admin_supplier_path(supplier, tab: 'contacts')

    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-contacts')
    expect(cards.length).to eq(8)
    expect(panel['data-supplier-contacts-next-page-value']).to eq('2')
    expect(panel.at_css('[data-supplier-contacts-target="count"]').text).to eq('19')

    get contacts_page_admin_supplier_path(supplier), params: { page: 2 }
    expect(response).to have_http_status(:ok)
    expect(cards.length).to eq(8)
    expect(response.headers['X-Next-Page']).to eq('3')
    expect(response.headers['X-Contacts-Count']).to eq('19')

    get contacts_page_admin_supplier_path(supplier), params: { page: 3 }
    expect(cards.length).to eq(3)
    expect(response.headers['X-Next-Page']).to eq('')
  end

  it 'applies search and filters to server paginated cards' do
    contact = create(:contact, contactable: supplier, name: 'Maria Purchasing', position: 'Procurement', primary: true)
    create(:contact, :inactive, contactable: supplier, name: 'Inactive Logistics')

    get contacts_page_admin_supplier_path(supplier), params: { q: 'Maria', filter: 'primary' }

    expect(response).to have_http_status(:ok)
    expect(cards.pluck('data-supplier-contact-id')).to eq([contact.id.to_s])
    expect(response.headers['X-Contacts-Count']).to eq('1')

    get contacts_page_admin_supplier_path(supplier), params: { filter: 'inactive' }
    expect(cards.length).to eq(1)
    expect(cards.first.text).to include('Inactive Logistics')
  end

  it 'isolates supplier contacts across organizations and ignores deleted contacts' do
    create(:contact, :deleted, contactable: supplier, name: 'Deleted Contact')
    other = create(:supplier, organization: create(:organization))
    create(:contact, contactable: other, name: 'Secret Contact')

    get contacts_page_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Contacts-Count']).to eq('0')
    expect(response.body).not_to include('Secret Contact', 'Deleted Contact')

    get contacts_page_admin_supplier_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it 'hides card edit options for users without contact management permission' do
    create(:contact, contactable: supplier, name: 'Read Only Contact')
    allow_any_instance_of(SupplierPolicy).to receive(:manage_contacts?).and_return(false)

    get admin_supplier_path(supplier, tab: 'contacts')

    expect(cards.length).to eq(1)
    expect(cards.first.css('details')).to be_empty

    get contacts_page_admin_supplier_path(supplier)
    expect(cards.first.css('details')).to be_empty
  end

  it 'requires authorization for the asynchronous contact endpoint' do
    allow_any_instance_of(SupplierPolicy).to receive(:view_contacts?).and_return(false)

    get contacts_page_admin_supplier_path(supplier)

    expect(response).to have_http_status(:forbidden)
  end

  it 'keeps an empty state when no supplier contacts are registered' do
    get admin_supplier_path(supplier, tab: 'contacts')

    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-contacts')
    expect(panel.at_css('[data-supplier-contacts-target="empty"]')['class']).not_to include('hidden')
    expect(panel['data-supplier-contacts-next-page-value']).to eq('0')
  end
end
