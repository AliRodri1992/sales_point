# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::SaveAddress do
  let(:supplier) { create(:supplier) }

  it 'atomically demotes the old primary on a form update' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    target = create(:address, :fiscal, addressable: supplier)
    target.primary = true

    expect(described_class.new(supplier:, address: target).call).to be true
    expect(previous.reload).not_to be_primary
    expect(target.reload).to be_primary
  end

  it 'rolls back demotion when the new primary is invalid' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    target = build(:address, :fiscal, addressable: supplier, primary: true, street: nil)

    expect(described_class.new(supplier:, address: target).call).to be false
    expect(target.errors[:street]).to be_present
    expect(previous.reload).to be_primary
  end

  it 'handles a change of address purpose without duplicate primaries' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    target = create(:address, :delivery, :primary, addressable: supplier)
    target.purpose = 'fiscal'

    expect(described_class.new(supplier:, address: target).call).to be true
    expect(previous.reload).not_to be_primary
    expect(target.reload).to have_attributes(purpose: 'fiscal', primary: true)
  end
end
