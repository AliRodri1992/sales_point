# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier audit versions' do
  let(:supplier) { create(:supplier) }

  it 'records supplier modifications in PaperTrail' do
    supplier.update!(name: 'Audited supplier')

    expect(supplier.versions.last).to have_attributes(event: 'update')
  end

  it 'records changes to supplier contacts' do
    contact = create(:contact, contactable: supplier)
    contact.update!(name: 'Audited contact')

    expect(contact.versions.last).to have_attributes(event: 'update')
  end

  it 'does not version addresses belonging to other resource types' do
    branch = create(:branch)
    address = branch.address

    address.update!(street: 'Different street')

    expect(address.versions).to be_empty
  end
end
