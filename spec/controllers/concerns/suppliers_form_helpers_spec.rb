# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SuppliersFormHelpers do
  let(:supplier) { create(:supplier) }
  let(:handler) { Class.new { include SuppliersFormHelpers }.new }

  before { handler.instance_variable_set(:@supplier, supplier) }

  def valid_records?(records, creating: false)
    handler.send(:valid_primary_records?, records, :contacts, creating:)
  end

  it 'accepts omitted nested contact records' do
    expect(valid_records?(nil)).to be(true)
  end

  it 'rejects an attempt to submit multiple primary contacts' do
    expect(valid_records?([{ name: 'First' }, { name: 'Second' }])).to be(false)
  end

  it 'rejects a nested destroy flag even for a primary contact' do
    contact = supplier.contacts.create!(name: 'Primary', primary: true)
    expect(valid_records?([{ id: contact.id, _destroy: '1' }])).to be(false)
  end

  it 'rejects unchecking the primary contact flag' do
    expect(valid_records?([{ name: 'No primary', primary: '0' }])).to be(false)
  end

  it 'blocks editing another contact through the primary-only form' do
    supplier.contacts.create!(name: 'Primary', primary: true)
    secondary = supplier.contacts.create!(name: 'Secondary')
    expect(valid_records?([{ id: secondary.id, name: 'Tampered' }])).to be(false)
  end

  it 'permits updating the actual primary contact' do
    primary = supplier.contacts.create!(name: 'Primary', primary: true)
    expect(valid_records?([{ id: primary.id, name: 'Updated' }])).to be(true)
  end

  it 'rejects existing contact identifiers during new registration' do
    contact = supplier.contacts.create!(name: 'Primary', primary: true)
    expect(valid_records?([{ id: contact.id }], creating: true)).to be(false)
    expect(valid_records?([{ name: 'New' }], creating: true)).to be(true)
  end

  it 'does not allow replacing an already established primary contact' do
    expect(valid_records?([{ name: 'New primary' }])).to be(true)
    supplier.contacts.create!(name: 'Existing', primary: true)
    expect(valid_records?([{ name: 'Injected replacement' }])).to be(false)
  end

  it 'rejects a nonfiscal primary address purpose' do
    expect(handler.send(:valid_primary_flags?, { purpose: 'delivery' }, :addresses)).to be(false)
    expect(handler.send(:valid_primary_flags?, { purpose: 'fiscal' }, :addresses)).to be(true)
  end

  it 'normalizes both primary flags and forces the nested address to fiscal' do
    contact = { name: 'Main' }
    address = { street: 'Central' }
    params = {
      contacts_attributes: { '0' => contact },
      addresses_attributes: [address]
    }
    result = handler.send(:normalize_primary_dossier_attributes!, params)

    expect(result).to equal(params)
    expect(contact[:primary]).to be(true)
    expect(address).to include(primary: true, purpose: 'fiscal')
  end

  it 'rejects a nonexistent contact id rather than treating it as a new contact' do
    expect(valid_records?([{ id: 999_999_999, name: 'Tampered' }])).to be(false)
  end

  it 'requires a primary fiscal address when a new address is submitted' do
    expect(handler.send(:valid_primary_records?,
                        [{ street: 'New fiscal address', purpose: 'fiscal' }],
                        :addresses, creating: false)).to be(true)
    supplier.addresses.create!(
      purpose: 'fiscal', primary: true, country: create(:country, iso_alpha2: 'MX'),
      street: 'Existing fiscal address', city: 'Mexico City', state: 'CDMX',
      neighborhood: 'Centro', postal_code: '06000'
    )
    expect(handler.send(:valid_primary_records?,
                        [{ street: 'Another fiscal address', purpose: 'fiscal' }],
                        :addresses, creating: false)).to be(false)
  end

  it 'ignores empty nested collections during normalization' do
    attrs = { contacts_attributes: {}, addresses_attributes: nil }

    expect(handler.send(:normalize_primary_dossier_attributes!, attrs)).to eq(attrs)
  end

  it 'does not enqueue geocoding for unsaved addresses' do
    supplier.addresses.build(
      purpose: 'delivery', country: create(:country, iso_alpha2: 'MX'),
      street: 'Unstored Street', city: 'Mexico City'
    )
    allow(GeocodeAddressJob).to receive(:perform_later)

    handler.send(:enqueue_nested_address_geocoding)

    expect(GeocodeAddressJob).not_to have_received(:perform_later)
  end
end
