# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::DossierContactsPage do
  let(:supplier) { create(:supplier) }

  def page(**options)
    described_class.new(supplier:, **options).call
  end

  it 'limits each page to eight records and returns the next page when available' do
    19.times { |index| create(:contact, contactable: supplier, name: format('Contact %02d', index)) }

    first = page
    second = page(page: 2)
    third = page(page: 3)

    expect(first.contacts.size).to eq(8)
    expect(first.total_count).to eq(19)
    expect(first.next_page).to eq(2)
    expect(second.contacts.size).to eq(8)
    expect(second.next_page).to eq(3)
    expect(third.contacts.size).to eq(3)
    expect(third.next_page).to be_nil
    expect((first.contacts + second.contacts + third.contacts).map(&:id).uniq.size).to eq(19)
  end

  it 'lists primary contacts before other contacts' do
    create(:contact, contactable: supplier, name: 'Regular Contact')
    primary = create(:contact, contactable: supplier, name: 'Primary Contact', primary: true)

    expect(page.contacts.first.id).to eq(primary.id)
  end

  it 'excludes soft-deleted contacts and contacts of other suppliers' do
    create(:contact, :deleted, contactable: supplier, name: 'Removed Person')
    create(:contact, contactable: create(:supplier), name: 'Other Supplier')
    current = create(:contact, contactable: supplier, name: 'Current Person')

    result = page

    expect(result.contacts.map(&:id)).to eq([current.id])
    expect(result.total_count).to eq(1)
  end

  it 'searches name, position, email and both phone numbers without wildcard surprises' do
    attributes = {
      name: 'Patricia González', position: 'Purchasing',
      email: 'patricia@contacts.example', phone: '5512345678', mobile_phone: '5587654321'
    }
    target = create(:contact, contactable: supplier, **attributes)
    create(:contact, contactable: supplier, name: 'Another Person')

    %w[Patricia Purchasing contacts.example 5512345678 5587654321].each do |term|
      expect(page(query: term).contacts.map(&:id)).to eq([target.id])
    end
    expect(page(query: '%').contacts).to be_empty
    expect(page(query: '_').contacts).to be_empty
  end

  it 'filters by primary and active status using real contact attributes' do
    primary = create(:contact, contactable: supplier, name: 'Primary', primary: true)
    inactive = create(:contact, :inactive, contactable: supplier, name: 'Inactive')
    active = create(:contact, contactable: supplier, name: 'Active')

    expect(page(filter: 'primary').contacts.map(&:id)).to eq([primary.id])
    expect(page(filter: 'inactive').contacts.map(&:id)).to eq([inactive.id])
    expect(page(filter: 'active').contacts.map(&:id)).to contain_exactly(primary.id, active.id)
    expect(page(filter: 'unexpected').total_count).to eq(3)
  end

  it 'treats blank and invalid pages as the first page' do
    create(:contact, contactable: supplier)

    expect(page(page: 'invalid').page).to eq(1)
    expect(page(page: -2).contacts.size).to eq(1)
  end

  it 'returns an empty page when no contacts match the search' do
    create(:contact, contactable: supplier, name: 'One Person')

    result = page(query: 'Not Found')

    expect(result.total_count).to be_zero
    expect(result.contacts).to be_empty
    expect(result.next_page).to be_nil
  end
end
