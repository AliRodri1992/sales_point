# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Phone, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:contact) { create(:contact, contactable: supplier, primary: true) }

  it 'normalizes Mexican mobile numbers to E.164 and inherits organization' do
    phone = contact.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)

    expect(phone.number).to eq('+525512345678')
    expect(phone.organization).to eq(organization)
  end

  it 'permits one office and one mobile primary for the same contact' do
    contact.phones.create!(number: '55 1234 5678', kind: 'landline', primary: true)
    mobile = contact.phones.create!(number: '55 8765 4321', kind: 'mobile', primary: true)

    expect(mobile).to be_persisted
  end

  it 'rejects a second active primary of the same type' do
    contact.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)
    second = contact.phones.build(number: '55 8765 4321', kind: 'mobile', primary: true)

    expect(second).not_to be_valid
    expect(second.errors.attribute_names).to include(:primary)
  end

  it 'prevents assignment to a different organization' do
    phone = contact.phones.build(
      number: '55 1234 5678', kind: 'mobile', organization: create(:organization)
    )

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:organization)
  end

  it 'rejects invalid numbers' do
    phone = contact.phones.build(number: 'abc', kind: 'mobile')

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:number)
  end

  it 'permits a number after archiving its previous record' do
    existing = contact.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)
    existing.update!(deleted_at: Time.current)
    phone = contact.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)

    expect(phone).to be_persisted
  end

  it 'inherits the tenant from a supplier contact' do
    contact = create(:contact, contactable: supplier)
    phone = contact.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)

    expect(phone.organization).to eq(organization)
    expect(phone.phoneable).to eq(contact)
  end

  it 'allows secondary numbers of a kind that already has a primary' do
    contact.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)
    secondary = contact.phones.create!(number: '55 8765 4321', kind: 'mobile', primary: false)

    expect(secondary).to be_persisted
    expect(secondary).not_to be_primary
  end

  it 'normalizes optional labels and extensions' do
    phone = contact.phones.create!(
      number: '55 1234 5678', kind: 'landline', label: ' Oficina ',
      extension: ' 123 '
    )

    expect(phone).to have_attributes(country_code: 'MX', label: 'Oficina', extension: '123')
  end

  it 'does not store an extension on a mobile number' do
    phone = contact.phones.create!(
      number: '55 1234 5678', kind: 'mobile', primary: true, extension: ' 123 '
    )

    expect(phone.extension).to be_nil
  end

  it 'clears the office extension when a number changes to mobile' do
    phone = contact.phones.create!(
      number: '55 1234 5678', kind: 'landline', primary: true, extension: '123'
    )

    phone.update!(kind: 'mobile')

    expect(phone.reload.extension).to be_nil
  end

  it 'rejects an invalid country code even with a valid Mexican number' do
    phone = contact.phones.build(number: '+525512345678', country_code: 'X', kind: 'mobile')

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:country_code)
  end

  it 'requires a phone owner and a number' do
    phone = described_class.new(organization:, kind: 'mobile')

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:phoneable, :number)
  end

  it 'stores both supplier onboarding numbers on its primary contact' do
    new_supplier = build(:supplier, organization:)
    main_contact = new_supplier.contacts.build(
      name: 'Compras', primary: true,
      phones_attributes: [
        { kind: 'landline', number: '55 2234 5678', primary: true },
        { kind: 'mobile', number: '55 1234 5678', primary: true }
      ]
    )

    expect(new_supplier.save).to be(true)
    expect(main_contact.reload.phones.active.pluck(:kind)).to match_array(%w[landline mobile])
    expect(new_supplier).not_to respond_to(:phones)
  end

  it 'forbids directly assigning supplier as the polymorphic phone owner' do
    phone = described_class.new(phoneable: supplier, organization:, number: '55 1234 5678',
                                kind: 'mobile', primary: true)

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:phoneable_type)
  end

  it 'rejects a duplicate number even for another type with no extension' do
    contact.phones.create!(number: '55 1234 5678', kind: 'landline', primary: true)
    duplicate = contact.phones.build(number: '55 1234 5678', kind: 'mobile', primary: true)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.attribute_names).to include(:number)
  end

  it 'limits client, branch and employee phones to the primary mobile' do
    [build(:client), build(:branch, organization:), build(:employee, organization:)].each do |owner|
      phone = owner.phones.build(number: '55 1234 5678', organization:, kind: 'landline', primary: true)
      expect(phone).not_to be_valid
      expect(phone.errors.attribute_names).to include(:kind)
    end
  end

  it 'rejects secondary mobiles for organization contacts' do
    organization_contact = build(:contact, contactable: organization)
    secondary = organization_contact.phones.build(
      number: '55 1234 5678', organization:, kind: 'mobile', primary: false
    )

    expect(secondary).not_to be_valid
    expect(secondary.errors.attribute_names).to include(:primary)
  end
end
