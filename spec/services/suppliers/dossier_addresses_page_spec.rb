# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::DossierAddressesPage do
  let(:supplier) { create(:supplier) }

  def page(**options)
    described_class.new(supplier:, **options).call
  end

  it 'paginates addresses in groups of eight and returns the correct next page' do
    19.times { |i| create(:address, :delivery, addressable: supplier, street: "Delivery Street #{i}") }

    first = page
    second = page(page: 2)
    third = page(page: 3)

    expect(first.addresses.size).to eq(8)
    expect(first.total_count).to eq(19)
    expect(first.next_page).to eq(2)
    expect(second.addresses.size).to eq(8)
    expect(second.next_page).to eq(3)
    expect(third.addresses.size).to eq(3)
    expect(third.next_page).to be_nil
    expect((first.addresses + second.addresses + third.addresses).map(&:id).uniq.size).to eq(19)
  end

  it 'counts each address purpose and the primary addresses independently of the selected filter' do
    create(:address, :fiscal, :primary, addressable: supplier)
    2.times { |i| create(:address, :delivery, addressable: supplier, street: "Delivery Address #{i}") }
    create(:address, addressable: supplier, purpose: 'commercial')
    create(:address, addressable: supplier, purpose: 'general')

    counts = { 'all' => 5, 'fiscal' => 1, 'delivery' => 2, 'commercial' => 1,
               'general' => 1, 'primary' => 1 }

    Suppliers::DossierAddressesPage::FILTERS.each do |filter|
      result = page(filter:)
      expect(result.filter_counts).to eq(counts)
      expect(result.total_count).to eq(counts.fetch(filter))
    end
  end

  it 'prioritizes principal addresses in the card list' do
    create(:address, :fiscal, addressable: supplier)
    primary = create(:address, :delivery, :primary, addressable: supplier)

    expect(page.addresses.first.id).to eq(primary.id)
  end

  it 'excludes deleted addresses and those belonging to other suppliers' do
    create(:address, :fiscal, :deleted, addressable: supplier)
    create(:address, :delivery, addressable: create(:supplier))
    current = create(:address, :delivery, addressable: supplier)

    expect(page.addresses.map(&:id)).to eq([current.id])
    expect(page.filter_counts['all']).to eq(1)
    expect(page.filter_counts['fiscal']).to eq(0)
  end

  it 'searches optional address references without matching unrelated suppliers' do
    match = create(:address, :fiscal, addressable: supplier, reference_notes: 'Portón AZUL del edificio')
    create(:address, :delivery, addressable: supplier, reference_notes: 'Portón verde')
    create(:address, :general, addressable: create(:supplier), reference_notes: 'Portón AZUL')

    expect(page(query: 'azul').addresses.pluck(:id)).to eq([match.id])
    expect(page(query: '%').addresses).to be_empty
  end

  it 'paginates deleted addresses separately from active ones and filters their types' do
    active = create(:address, :fiscal, addressable: supplier)
    18.times do |i|
      create(:address, :delivery, addressable: supplier, street: "Archived #{i}",
             reference_notes: "Old warehouse #{i}", deleted_at: Time.current)
    end
    first = page(status: 'deleted')
    second = page(status: 'deleted', page: 2)
    third = page(status: 'deleted', page: 3)

    expect(first.addresses.size).to eq(8)
    expect(first.filter_counts['delivery']).to eq(18)
    expect(first.filter_counts['fiscal']).to eq(0)
    expect(first.next_page).to eq(2)
    expect(second.addresses.size).to eq(8)
    expect(third.addresses.size).to eq(2)
    expect(third.next_page).to be_nil
    expect((first.addresses + second.addresses + third.addresses).pluck(:id).uniq.size).to eq(18)
    expect(page(status: 'deleted', query: 'warehouse 12', filter: 'delivery').total_count).to eq(1)
    expect(page.addresses.pluck(:id)).to eq([active.id])
    expect(page(status: 'unexpected').addresses.pluck(:id)).to eq([active.id])
  end

  it 'searches street, address details, postal code and country, ignoring case' do
    country = create(:country, name: 'Exampleland')
    attributes = {
      country:, street: 'Calle del Sol', city: 'Pueblo Norte',
      neighborhood: 'Vista Bella', postal_code: '54831'
    }
    target = create(:address, :delivery, addressable: supplier, **attributes)
    create(:address, :fiscal, addressable: supplier, street: 'Different Street')

    ['calle del sol', 'Pueblo Norte', 'Vista Bella', '54831', 'Exampleland'].each do |term|
      expect(page(query: term).addresses.map(&:id)).to eq([target.id])
    end
    expect(page(query: '%').addresses).to be_empty
    expect(page(query: '_').addresses).to be_empty
  end

  it 'updates all type counters for the current search even when a type is selected' do
    create(:address, :fiscal, :primary, addressable: supplier, city: 'Monterrey')
    create(:address, :delivery, addressable: supplier, city: 'Monterrey')
    create(:address, :delivery, addressable: supplier, city: 'Puebla')

    result = page(query: 'Monterrey', filter: 'delivery')

    expect(result.filter_counts).to eq(
      'all' => 2, 'fiscal' => 1, 'delivery' => 1,
      'commercial' => 0, 'general' => 0, 'primary' => 1
    )
    expect(result.addresses.size).to eq(1)
    expect(result.total_count).to eq(1)
  end

  it 'returns zero counts for all types when no addresses match' do
    create(:address, :fiscal, addressable: supplier)

    expect(page(query: 'Nothing matches').filter_counts.values).to eq([0, 0, 0, 0, 0, 0])
  end

  it 'defaults unknown types and invalid page numbers safely' do
    create(:address, :fiscal, addressable: supplier)

    expect(page(filter: 'unrecognized').total_count).to eq(1)
    expect(page(page: 'invalid').page).to eq(1)
    expect(page(page: -1).addresses.size).to eq(1)
  end
end
