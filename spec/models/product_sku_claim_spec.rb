# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shared product and variant SKU reservations' do
  let(:organization) { create(:organization) }

  it 'reserves each product and variant SKU in the same organization-wide namespace' do
    product = create(:product, organization:, sku: 'COFFEE-BEAN-01')
    parent = create(:product, organization:)
    variant = parent.product_variants.create!(name: 'Whole bean', sku: 'WHOLE-BEAN-02')

    expect(ProductSkuClaim.find_by!(owner_type: 'Product', owner_id: product.id).normalized_sku)
      .to eq('coffee-bean-01')
    expect(ProductSkuClaim.find_by!(owner_type: 'ProductVariant', owner_id: variant.id).normalized_sku)
      .to eq('whole-bean-02')
    expect(build(:product, organization:, sku: 'whole-bean-02')).not_to be_valid
    expect(parent.product_variants.build(name: 'Collision', sku: 'coffee-bean-01')).not_to be_valid
  end

  it 'releases the previous SKU when changed or soft-deleted' do
    product = create(:product, organization:, sku: 'OLD-CLAIM')
    product.update!(sku: 'NEW-CLAIM')

    expect(ProductSkuClaim.where(organization:, normalized_sku: 'old-claim')).to be_empty
    expect(ProductSkuClaim.where(organization:, normalized_sku: 'new-claim').count).to eq(1)

    product.update!(deleted_at: Time.current)
    expect(ProductSkuClaim.where(organization:, normalized_sku: 'new-claim')).to be_empty
    expect(create(:product, organization:, sku: 'OLD-CLAIM')).to be_present
  end

  it 'enforces shared uniqueness in PostgreSQL independently of the model validation' do
    first = create(:product, organization:, sku: 'ALREADY-RESERVED')
    alternate = create(:product, organization:)
    expect do
      ProductSkuClaim.transaction(requires_new: true) do
        # Simulate the racing second claimant after the first reservation commits.
        ProductSkuClaim.create!(organization:, normalized_sku: 'already-reserved',
                                owner_type: 'ProductVariant', owner_id: alternate.id)
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
    expect(ProductSkuClaim.where(organization:, normalized_sku: 'already-reserved').sole.owner_id)
      .to eq(first.id)
  end

  it 'serializes two concurrent claimant inserts', :concurrent_db do
    organization
    first = create(:product, organization:)
    second = create(:product, organization:)
    ready = Queue.new
    go = Queue.new
    results = Queue.new

    workers = [first, second].map do |record|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          begin
            ProductSkuClaim.create!(organization_id: organization.id, owner_type: 'Product',
                                    owner_id: record.id, normalized_sku: 'concurrent-key')
            results << :created
          rescue ActiveRecord::RecordNotUnique
            results << :conflict
          end
        end
      end
    end
    2.times { ready.pop }
    2.times { go << true }
    workers.each(&:join)

    expect([results.pop, results.pop].sort).to eq(%i[conflict created])
    expect(ProductSkuClaim.where(organization:, normalized_sku: 'concurrent-key').count).to eq(1)
  end
end
