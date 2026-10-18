# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::PreferredSupplier, type: :model, concurrent_db: true do
  self.use_transactional_tests = false

  let!(:organization) { create(:organization) }
  let!(:product) { create(:product, organization:) }
  let!(:first_supplier) { create(:supplier, organization:) }
  let!(:second_supplier) { create(:supplier, organization:) }

  before do
    [first_supplier, second_supplier].each do |supplier|
      SupplierProduct.create!(
        organization:, product:, supplier:, currency: supplier.currency,
        presentation_name: 'Unit', units_per_package: 1, purchase_price: 10
      )
    end
  end

  def change_to(supplier, expected: nil)
    described_class.call(product: product.reload, supplier:, expected_supplier_id: expected)
  end

  it 'chooses only one preferred supplier, not one presentation' do
    change_to(first_supplier)

    expect(product.reload.preferred_supplier).to eq(first_supplier)
    offers = first_supplier.supplier_products
    expect(offers.first).to be_preferred

    SupplierProduct.create!(
      organization:, product:, supplier: first_supplier, currency: first_supplier.currency,
      presentation_name: 'Box', units_per_package: 12, purchase_price: 100
    )
    expect(offers.reload).to all(be_preferred)
  end

  it 'requires an up-to-date expected supplier before replacing the preference' do
    change_to(first_supplier)

    expect { change_to(second_supplier) }.to raise_error(described_class::Conflict)
    expect(product.reload.preferred_supplier).to eq(first_supplier)

    change_to(second_supplier, expected: first_supplier.id)
    expect(product.reload.preferred_supplier).to eq(second_supplier)
    expect(first_supplier.supplier_products.first).not_to be_preferred
  end

  it 'allows removing the preference without choosing a replacement' do
    change_to(first_supplier)
    change_to(nil, expected: first_supplier.id)

    expect(product.reload.preferred_supplier).to be_nil
  end

  it 'does not allow inactive or foreign-organization supplier choices' do
    first_supplier.supplier_products.update_all(active: false)
    expect { change_to(first_supplier) }.to raise_error(described_class::Unavailable)

    foreign = create(:supplier, organization: create(:organization))
    expect { change_to(foreign) }.to raise_error(described_class::Unavailable)
    expect(product.reload.preferred_supplier).to be_nil
  end

  it 'does not overwrite an earlier concurrent selection' do
    gate = Queue.new
    candidates = [first_supplier.id, second_supplier.id]
    threads = candidates.map do |supplier_id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            described_class.call(
              product: Product.find(product.id), supplier: Supplier.find(supplier_id),
              expected_supplier_id: nil
            )
            :saved
          rescue described_class::Conflict
            :conflict
          end
        end
      end
    end

    candidates.size.times { gate << true }
    expect(threads.map(&:value).sort).to eq(%i[conflict saved])
    expect(candidates).to include(product.reload.preferred_supplier_id)
  ensure
    threads&.each { |thread| thread.join if thread.alive? }
  end

  it 'serializes a preferred selection with disabling the last offer' do
    change_to(first_supplier)
    offer = first_supplier.supplier_products.first
    offer.update!(active: false)

    expect(product.reload.preferred_supplier).to be_nil
    expect { change_to(first_supplier) }.to raise_error(described_class::Unavailable)
  end
end
