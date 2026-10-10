# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::ProductsLookup do
  subject(:host) { host_class.new }

  let(:host_class) do
    Class.new do
      include Admin::ProductsLookup

      attr_accessor :params
    end
  end

  before { host.params = ActionController::Parameters.new }

  describe '#find_product_by_id_or_slug' do
    it 'finds a non-deleted product by numeric id' do
      product = create(:product)

      expect(host.send(:find_product_by_id_or_slug, product.id.to_s)).to eq(product)
    end

    it 'finds a product by slug' do
      product = create(:product, slug: 'coffee-beans')

      expect(host.send(:find_product_by_id_or_slug, 'coffee-beans')).to eq(product)
    end

    it 'falls back to a case-insensitive slug or uppercase product code lookup' do
      product = create(:product, code: 'SKU-LOOKUP', slug: 'unique-item')

      expect(host.send(:find_product_by_id_or_slug, 'SKU-LOOKUP')).to eq(product)
      expect(host.send(:find_product_by_id_or_slug, 'UNIQUE-ITEM')).to eq(product)
    end

    it 'does not find a soft-deleted product' do
      product = create(:product, :deleted, slug: 'retired-item')

      expect(host.send(:find_product_by_id_or_slug, product.id.to_s)).to be_nil
      expect(host.send(:find_product_by_id_or_slug, 'retired-item')).to be_nil
    end

    it 'returns nil when no id, slug, or code matches' do
      expect(host.send(:find_product_by_id_or_slug, 'missing-product')).to be_nil
    end
  end

  describe '#set_product' do
    it 'assigns the resolved product' do
      product = create(:product)
      host.params = ActionController::Parameters.new(id: product.id.to_s)

      host.send(:set_product)

      expect(host.instance_variable_get(:@product)).to eq(product)
    end

    it 'raises RecordNotFound when no product matches' do
      host.params = ActionController::Parameters.new(id: 'missing-product')

      expect { host.send(:set_product) }.to raise_error(ActiveRecord::RecordNotFound, 'Product not found')
    end
  end
end
