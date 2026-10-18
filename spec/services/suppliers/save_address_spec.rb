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
  it 'serializes competing primary selections using real PostgreSQL connections', :concurrent_db do
    addresses = Array.new(2) { create(:address, :fiscal, addressable: supplier) }
    supplier_id = supplier.id
    barrier = Queue.new
    outcomes = Queue.new
    threads = addresses.map do |address|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          locked_supplier = Supplier.find(supplier_id)
          target = Address.find(address.id)
          target.primary = true
          outcomes << described_class.new(supplier: locked_supplier, address: target).call
        end
      end
    end
    addresses.size.times { barrier << true }
    threads.each(&:value)

    expect(outcomes.size).to eq(2)
    expect(Supplier.find(supplier_id).addresses.where(purpose: 'fiscal', primary: true).count).to eq(1)
  end

end
