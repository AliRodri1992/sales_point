# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SuppliersFormHelpers do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:host) do
    Class.new do
      include SuppliersFormHelpers

      def initialize(record)
        @supplier = record
      end
    end.new(supplier)
  end

  def accepts?(record, association: :contacts, creating: false)
    host.send(:valid_primary_record?, record, association, creating:)
  end

  it 'accepts an omitted contact or address collection' do
    expect(host.send(:valid_primary_records?, nil, :contacts, creating: true)).to be(true)
    expect(host.send(:valid_primary_records?, {}, :addresses, creating: false)).to be(true)
  end

  it 'rejects multiple nested contacts in the supplier registration flow' do
    records = { '0' => { name: 'Primary' }, '1' => { name: 'Secondary' } }
    expect(host.send(:valid_primary_records?, records, :contacts, creating: true)).to be(false)
  end

  it 'rejects an existing contact ID presented as a new record' do
    expect(accepts?({ id: 15, name: 'Forged' }, creating: true)).to be(false)
  end

  it 'rejects nested primary records marked for deletion' do
    expect(accepts?({ _destroy: '1' }, creating: true)).to be(false)
    expect(accepts?({ _destroy: true }, creating: true)).to be(false)
  end

  it 'rejects attempts to unmark the required principal record' do
    expect(accepts?({ primary: '0' }, creating: true)).to be(false)
    expect(accepts?({ primary: false }, creating: true)).to be(false)
  end

  it 'refuses to substitute a shipping address for the fiscal principal' do
    expect(accepts?({ purpose: 'delivery' }, association: :addresses, creating: true)).to be(false)
  end

  it 'accepts the first fiscal address or contact when no primary exists' do
    expect(accepts?({ name: 'First' })).to be(true)
    expect(accepts?({ purpose: 'fiscal' }, association: :addresses)).to be(true)
  end

  it 'rejects a second principal contact when a primary already exists' do
    supplier.contacts.create!(name: 'Existing primary', primary: true)
    expect(accepts?({ name: 'Another primary' })).to be(false)
  end

  it 'accepts edits to the existing primary contact but not a secondary contact' do
    primary = supplier.contacts.create!(name: 'Main', primary: true)
    other = supplier.contacts.create!(name: 'Other', primary: false)
    expect(accepts?({ id: primary.id, name: 'Updated' })).to be(true)
    expect(accepts?({ id: other.id, name: 'Forged' })).to be(false)
  end

  it 'rejects a new fiscal principal when the supplier already has one' do
    create(:address, addressable: supplier, purpose: 'fiscal', primary: true)
    expect(accepts?({ purpose: 'fiscal' }, association: :addresses)).to be(false)
  end

  it 'normalizes a single contact and fiscal address as primary without removing data' do
    contacts = { '0' => { name: 'Main contact', primary: false } }
    addresses = { '0' => { street: 'Main address', purpose: 'delivery', primary: false } }
    params = { contacts_attributes: contacts, addresses_attributes: addresses }

    host.send(:normalize_primary_dossier_attributes!, params)

    expect(contacts['0']).to include(name: 'Main contact', primary: true)
    expect(addresses['0']).to include(street: 'Main address', purpose: 'fiscal', primary: true)
  end
end
