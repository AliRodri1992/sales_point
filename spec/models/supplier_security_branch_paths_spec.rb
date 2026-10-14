# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier fiscal data, contact and document safeguards' do
  let(:organization) { create(:organization) }

  it 'normalizes whitespace in identity and business fields' do
    supplier = build(:supplier, organization:, code: '  SUP-X33  ', name: '  Store  ',
                                email: '  OWNER@EXAMPLE.COM ', phone: '5512345678')
    supplier.valid?
    expect(supplier).to have_attributes(
      code: 'SUP-X33', name: 'Store', email: 'owner@example.com'
    )
    expect(supplier.phone).to start_with('+52')
  end

  it 'normalizes unique supplier tags and rejects duplicate descriptions' do
    supplier = build(:supplier, organization:)
    supplier.tags_text = ' primary, retail, primary, , retail '
    expect(supplier.tags).to eq(%w[primary retail])
    expect(supplier.tags_text).to eq('primary, retail')
  end

  it 'limits the number of supplier tags to twenty' do
    supplier = build(:supplier, organization:)
    supplier.tags_text = (1..25).map { |n| "tag#{n}" }.join(',')
    expect(supplier.tags.size).to eq(20)
  end

  it 'rejects invalid supplier RFC calendar dates' do
    supplier = build(:supplier, organization:, rfc: 'XAXX991332001')
    supplier.valid?
    expect(supplier.errors[:rfc]).to be_present
  end

  it 'rejects a corporation with a 13-character individual RFC' do
    supplier = build(:supplier, organization:, person_type: 'company')
    supplier.valid?
    expect(supplier.errors[:rfc]).to be_present
  end

  it 'rejects a person with a 12-character company RFC' do
    supplier = build(:supplier, organization:, person_type: 'individual', rfc: 'ABC010101AB1')
    supplier.valid?
    expect(supplier.errors[:rfc]).to be_present
  end

  it 'does not attempt RFC date parsing on an empty value' do
    supplier = build(:supplier, organization:, rfc: '')
    expect { supplier.valid? }.not_to raise_error
    expect(supplier.errors[:rfc]).to be_present
  end

  it 'does not attempt RFC date parsing on malformed content' do
    supplier = build(:supplier, organization:, rfc: 'invalid!!!')
    expect { supplier.valid? }.not_to raise_error
    expect(supplier.errors[:rfc]).to be_present
  end

  it 'rejects responsible users that do not belong to the supplier organization' do
    supplier = build(:supplier, organization:, responsible_user: create(:user))
    supplier.valid?
    expect(supplier.errors[:responsible_user]).to be_present
  end

  it 'accepts a responsible user belonging to the supplier organization' do
    user = create(:user)
    create(:organization_membership, organization:, user:)
    supplier = build(:supplier, organization:, responsible_user: user)
    supplier.valid?
    expect(supplier.errors[:responsible_user]).to be_empty
  end

  it 'allows suppliers to omit their internal responsible user' do
    supplier = build(:supplier, organization:, responsible_user: nil)
    supplier.valid?
    expect(supplier.errors[:responsible_user]).to be_empty
  end

  it 'rejects invalid business contact numbers' do
    supplier = build(:supplier, organization:, phone: 'X12')
    supplier.valid?
    expect(supplier.errors[:phone]).to be_present
  end

  it 'allows optional supplier phone numbers to be left blank' do
    supplier = build(:supplier, organization:, phone: nil)
    supplier.valid?
    expect(supplier.errors[:phone]).to be_empty
  end

  it 'blocks potentially unsafe uploaded document MIME types' do
    supplier = build(:supplier, organization:)
    supplier.documents.attach(io: StringIO.new('malware'), filename: 'invoice.exe',
                              content_type: 'application/octet-stream')
    supplier.valid?
    expect(supplier.errors[:documents]).to be_present
  end

  it 'allows a small PDF document in the supplier dossier' do
    supplier = build(:supplier, organization:)
    supplier.documents.attach(io: StringIO.new('pdf-test'), filename: 'invoice.pdf',
                              content_type: 'application/pdf')
    supplier.valid?
    expect(supplier.errors[:documents]).to be_empty
  end
end
