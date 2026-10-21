# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Edit supplier primary records', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:supplier) { create(:supplier, organization:) }
  let(:country) { Country.find_by(iso_alpha2: 'MX') || create(:country, iso_alpha2: 'MX') }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
  end

  def address_attributes
    { country:, street: 'Main Street', exterior_number: '12',
      neighborhood: 'Centro', city: 'Mexico City', state: 'CDMX', postal_code: '06000' }
  end

  def form
    Nokogiri::HTML(response.body).at_css('form[data-controller="supplier-form"]')
  end

  def field_records(name)
    form.css(
      "[data-supplier-nested-item] input[name*='[#{name}_attributes]'][name$='[id]']"
    )
  end

  def nested_values(association, attribute)
    form.css("input[name*='[#{association}_attributes]'][name$='[#{attribute}]']").pluck('value')
  end

  it 'renders only the principal fiscal address and principal contact, without removal controls' do
    fiscal = supplier.addresses.create!(**address_attributes, purpose: 'fiscal', primary: true)
    supplier.addresses.create!(**address_attributes, street: 'Secondary Fiscal', purpose: 'fiscal')
    supplier.addresses.create!(**address_attributes, street: 'Primary Delivery', purpose: 'delivery', primary: true)
    main_contact = supplier.contacts.create!(name: 'Primary Contact', primary: true)
    supplier.contacts.create!(name: 'Secondary Contact')

    get edit_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(field_records('addresses').pluck('value').uniq).to eq([fiscal.id.to_s])
    expect(field_records('contacts').pluck('value').uniq).to eq([main_contact.id.to_s])
    expect(form.text).not_to include('Secondary Contact')
    expect(form.css('[data-action="supplier-nested#add"], [data-action="supplier-nested#remove"]')).to be_empty
    expect(form.css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_empty
    expect(form.css("a[href='#{admin_supplier_contacts_path(supplier)}']")).to be_empty
    labels = form.css('[data-supplier-nested-item] label, [data-supplier-nested-item] span')
                 .map { |node| node.text.strip }
    expect(labels).not_to include('Primary')
    expect(form.css('select[name*="[purpose]"]')).to be_empty
    expect(form.at_css('input[name$="[purpose]"][value="fiscal"]')).to be_present
    expect(form.at_css('input[name*="[addresses_attributes]"][name$="[primary]"][value="1"]')).to be_present
    expect(form.at_css('input[name*="[contacts_attributes]"][name$="[primary]"][value="1"]')).to be_present
    expect(nested_values('addresses', 'street')).to eq(['Main Street'])
    expect(nested_values('contacts', 'name')).to eq(['Primary Contact'])
  end

  it 'updates the principal records without changing secondary records' do
    fiscal = supplier.addresses.create!(**address_attributes, purpose: 'fiscal', primary: true)
    secondary_address = supplier.addresses.create!(**address_attributes, street: 'Keep Fiscal', purpose: 'fiscal')
    main_contact = supplier.contacts.create!(name: 'Primary Contact', primary: true)
    secondary_contact = supplier.contacts.create!(name: 'Keep Contact')
    get edit_admin_supplier_path(supplier)

    patch admin_supplier_path(supplier), params: { supplier: {
      addresses_attributes: { '0' => { id: fiscal.id, street: 'Updated Fiscal', purpose: 'fiscal', primary: '1' } },
      contacts_attributes: { '0' => { id: main_contact.id, name: 'Updated Primary', primary: '1' } }
    } }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(fiscal.reload).to have_attributes(street: 'Updated Fiscal', primary: true, purpose: 'fiscal')
    expect(main_contact.reload).to have_attributes(name: 'Updated Primary', primary: true)
    expect(secondary_address.reload.street).to eq('Keep Fiscal')
    expect(secondary_contact.reload.name).to eq('Keep Contact')
  end

  it 'rejects editing secondary records through crafted parameters' do
    primary = supplier.contacts.create!(name: 'Main', primary: true)
    secondary = supplier.contacts.create!(name: 'Other')
    patch admin_supplier_path(supplier), params: { supplier: {
      contacts_attributes: { '0' => { id: secondary.id, name: 'Tampered', primary: true } }
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(secondary.reload.name).to eq('Other')
    expect(primary.reload.name).to eq('Main')
  end

  it 'rejects multiple fiscal addresses in an update' do
    fiscal = supplier.addresses.create!(**address_attributes, purpose: 'fiscal', primary: true)
    patch admin_supplier_path(supplier), params: { supplier: { addresses_attributes: {
      '0' => { id: fiscal.id, street: 'Changed', primary: true },
      '1' => { **address_attributes, purpose: 'fiscal', primary: true }
    } } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(fiscal.reload.street).to eq('Main Street')
  end

  it 'does not show management links or secondary records when the primary is missing' do
    supplier.addresses.create!(**address_attributes, street: 'Only Secondary', purpose: 'fiscal')
    supplier.contacts.create!(name: 'Only Secondary Contact')

    get edit_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(form.css('input[name*="[addresses_attributes]"][name$="[primary]"][value="1"]')).to be_present
    expect(form.css('input[name*="[contacts_attributes]"][name$="[primary]"][value="1"]')).to be_present
    expect(form.at_css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_nil
    expect(form.at_css("a[href='#{admin_supplier_contacts_path(supplier)}']")).to be_nil
  end

  it 'keeps primary controls visible when creating a new supplier' do
    get new_admin_supplier_path

    expect(response).to have_http_status(:ok)
    expect(form.at_css('input[name*="[addresses_attributes]"][name$="[primary]"][type="checkbox"]')).to be_present
    expect(form.at_css('input[name*="[contacts_attributes]"][name$="[primary]"][type="checkbox"]')).to be_present
  end

  it 'keeps the primary fields visible after an invalid supplier update' do
    fiscal = supplier.addresses.create!(**address_attributes, purpose: 'fiscal', primary: true)
    main_contact = supplier.contacts.create!(name: 'Primary Contact', primary: true)
    supplier.contacts.create!(name: 'Secondary Contact')

    patch admin_supplier_path(supplier), params: { supplier: {
      name: '', addresses_attributes: { '0' => { id: fiscal.id, street: 'Edited Fiscal' } },
      contacts_attributes: { '0' => { id: main_contact.id, name: 'Edited Primary' } }
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(field_records('addresses').pluck('value').uniq).to eq([fiscal.id.to_s])
    expect(field_records('contacts').pluck('value').uniq).to eq([main_contact.id.to_s])
    expect(nested_values('addresses', 'street')).to eq(['Edited Fiscal'])
    expect(nested_values('contacts', 'name')).to eq(['Edited Primary'])
  end
end
