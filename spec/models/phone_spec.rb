# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Phone, type: :model do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }

  it 'normalizes Mexican mobile numbers to E.164 and inherits organization' do
    phone = supplier.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)

    expect(phone.number).to eq('+525512345678')
    expect(phone.organization).to eq(organization)
  end

  it 'permits one office and one mobile primary for the same supplier' do
    supplier.phones.create!(number: '55 1234 5678', kind: 'landline', primary: true)
    mobile = supplier.phones.create!(number: '55 8765 4321', kind: 'mobile', primary: true)

    expect(mobile).to be_persisted
  end

  it 'rejects a second active primary of the same type' do
    supplier.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)
    second = supplier.phones.build(number: '55 8765 4321', kind: 'mobile', primary: true)

    expect(second).not_to be_valid
    expect(second.errors.attribute_names).to include(:primary)
  end

  it 'prevents assignment to a different organization' do
    phone = supplier.phones.build(number: '55 1234 5678', kind: 'mobile',
                                  organization: create(:organization))

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:organization)
  end

  it 'rejects invalid numbers' do
    phone = supplier.phones.build(number: 'abc', kind: 'mobile')

    expect(phone).not_to be_valid
    expect(phone.errors.attribute_names).to include(:number)
  end

  it 'permits a number after archiving its previous record' do
    existing = supplier.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)
    existing.update!(deleted_at: Time.current)
    phone = supplier.phones.create!(number: '55 1234 5678', kind: 'mobile', primary: true)

    expect(phone).to be_persisted
  end
end
