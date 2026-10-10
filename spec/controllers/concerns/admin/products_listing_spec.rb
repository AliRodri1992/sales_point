# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::ProductsListing do
  subject(:host) { host_class.new }

  let(:host_class) do
    Class.new do
      include Admin::ProductsListing

      attr_accessor :params
    end
  end
  let(:scope) { Product.none }

  before { host.params = ActionController::Parameters.new }

  describe '#filter_scope' do
    it 'keeps the scope unchanged when no filters are supplied' do
      expect(host.send(:filter_scope, scope).to_sql).to eq(scope.to_sql)
    end

    it 'filters products by search term' do
      host.params = ActionController::Parameters.new(search: 'coffee')

      expect(host.send(:filter_scope, scope).to_sql).to include('ILIKE')
    end

    it 'filters featured products when selected' do
      host.params = ActionController::Parameters.new(featured: 'true')

      expect(host.send(:filter_scope, scope).to_sql).to include('"products"."featured" = TRUE')
    end

    it 'filters non-featured products when selected' do
      host.params = ActionController::Parameters.new(featured: 'false')

      expect(host.send(:filter_scope, scope).to_sql).to include('"products"."featured" = FALSE')
    end

    it 'filters by status unless all statuses are requested' do
      host.params = ActionController::Parameters.new(status: 'active')

      expect(host.send(:filter_scope, scope).to_sql).to include('"products"."status"')
      host.params = ActionController::Parameters.new(status: 'all')

      expect(host.send(:filter_scope, scope).to_sql).not_to include('"products"."status"')
    end
  end

  describe '#apply_sorting' do
    it 'uses a permitted column and direction' do
      host.params = ActionController::Parameters.new(sort: 'products.price', direction: 'desc')

      expect(host.send(:apply_sorting, scope).to_sql).to include('ORDER BY "products"."price" DESC')
    end

    it 'falls back to the name column and ascending direction for invalid input' do
      host.params = ActionController::Parameters.new(sort: 'unknown', direction: 'sideways')

      expect(host.send(:apply_sorting, scope).to_sql).to include('ORDER BY "products"."name" ASC')
    end
  end

  describe '#paginate' do
    it 'uses the default page size and clamps a page below one' do
      host.params = ActionController::Parameters.new(page: '-3')

      result = host.send(:paginate, scope)

      expect(result.to_sql).to include('LIMIT 10')
      expect(result.to_sql).to include('OFFSET 0')
      expect(host.instance_variable_get(:@total_pages)).to eq(1)
    end

    it 'uses a supported page size and clamps an excessive page to the last page' do
      host.params = ActionController::Parameters.new(page: '99', per_page: '5')
      allow(scope).to receive(:count).and_return(11)

      result = host.send(:paginate, scope)

      expect(result.to_sql).to include('LIMIT 5')
      expect(result.to_sql).to include('OFFSET 10')
    end

    it 'falls back to the default page size for an unsupported option' do
      host.params = ActionController::Parameters.new(per_page: '7')

      expect(host.send(:per_page_param)).to eq(10)
    end
  end
end
