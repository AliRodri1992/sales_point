require 'rails_helper'

RSpec.describe Contact, type: :model do
  it 'belongs polymorphically to an organization' do
    contact = create(:contact)
    expect(contact.contactable).to be_a(Organization)
  end

  it 'belongs polymorphically to a supplier' do
    contact = create(:contact, contactable: create(:supplier))
    expect(contact.contactable).to be_a(Supplier)
  end

  it 'exposes contacts and addresses through parent associations' do
    organization = create(:organization)
    supplier = create(:supplier)
    organization_contact = create(:contact, contactable: organization)
    supplier_contact = create(:contact, contactable: supplier)

    expect(organization.contacts).to include(organization_contact)
    expect(supplier.contacts).to include(supplier_contact)
    expect(organization.contacts).not_to include(supplier_contact)
  end

  it 'normalizes contact fields' do
    contact = build(:contact, name: '  Alice  ', email: '  ALICE@EXAMPLE.COM  ')
    contact.valid?
    expect(contact.name).to eq('Alice')
    expect(contact.email).to eq('alice@example.com')
  end

  it 'rejects invalid email addresses' do
    expect(build(:contact, email: 'invalid')).not_to be_valid
  end

  it 'allows only one active primary contact per entity' do
    organization = create(:organization)
    create(:contact, contactable: organization, primary: true)
    expect(build(:contact, contactable: organization, primary: true)).not_to be_valid
    expect(build(:contact, contactable: create(:organization), primary: true)).to be_valid
  end

  it 'ignores inactive and deleted primary contacts' do
    organization = create(:organization)
    create(:contact, contactable: organization, primary: true, active: false)
    create(:contact, contactable: organization, primary: true, deleted_at: Time.current)
    expect(build(:contact, contactable: organization, primary: true)).to be_valid
  end
end
