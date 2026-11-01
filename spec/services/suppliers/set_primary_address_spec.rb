# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::SetPrimaryAddress do
  let(:supplier) { create(:supplier) }

  def promote(address)
    described_class.new(supplier:, address:).call
  end

  it 'atomically replaces the existing primary of the same address type' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    target = create(:address, :fiscal, addressable: supplier)
    delivery = create(:address, :delivery, :primary, addressable: supplier)

    expect(promote(target)).to be true
    expect(target.reload).to be_primary
    expect(previous.reload).not_to be_primary
    expect(delivery.reload).to be_primary
    expect(Address.where(addressable: supplier, purpose: 'fiscal', primary: true).count).to eq(1)
  end

  it 'does not update an already primary address' do
    current = create(:address, :fiscal, :primary, addressable: supplier)

    expect(promote(current)).to be false
    expect(current.reload).to be_primary
  end

  it 'rejects addresses from other suppliers and soft-deleted addresses' do
    external = create(:address, :fiscal, addressable: create(:supplier))
    deleted = create(:address, :fiscal, :deleted, addressable: supplier)

    expect { promote(external) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { promote(deleted) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'rolls back the previous primary if promoting the new address fails' do
    previous = create(:address, :delivery, :primary, addressable: supplier)
    target = create(:address, :delivery, addressable: supplier)
    allow_any_instance_of(Address).to receive(:update!).and_call_original
    allow_any_instance_of(Address).to receive(:update!).with(primary: true).and_raise(
      ActiveRecord::RecordInvalid.new(target)
    )

    expect { promote(target) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(previous.reload).to be_primary
    expect(target.reload).not_to be_primary
  end

  it 'keeps a primary selection scoped to its supplier' do
    previous = create(:address, :fiscal, :primary, addressable: supplier)
    external_supplier = create(:supplier)
    external = create(:address, :fiscal, :primary, addressable: external_supplier)
    target = create(:address, :fiscal, addressable: supplier)

    promote(target)

    expect(previous.reload).not_to be_primary
    expect(external.reload).to be_primary
  end
end
