# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SuppliersListing do
  let(:actor) { create(:user) }
  let(:query) do
    Class.new do
      include Admin::SuppliersListing
      attr_accessor :params, :actor

      def current_user = actor
    end.new
  end

  before do
    query.params = ActionController::Parameters.new
    query.actor = actor
    allow(actor).to receive(:admin?).and_return(false)
    allow(actor).to receive(:permission?).with('suppliers.view').and_return(false)
  end

  it 'restricts sensitive sort keys to full-view users' do
    expect(query.send(:restricted_sort?, 'suppliers.rfc')).to be(true)
    expect(query.send(:restricted_sort?, 'suppliers.name')).to be(false)
    expect(query.send(:restricted_sort?, 'suppliers.status')).to be(false)
  end

  it 'permits full-view users to sort using fiscal columns' do
    allow(actor).to receive(:permission?).with('suppliers.view').and_return(true)

    expect(query.send(:restricted_sort?, 'suppliers.rfc')).to be(false)
  end

  it 'rejects arbitrary sorting and uses the public name column instead' do
    query.params = ActionController::Parameters.new(sort: 'email', direction: 'DROP TABLE')

    expect(query.send(:apply_sorting, Supplier.all).to_sql).to include('ORDER BY "suppliers"."name" ASC')
  end

  it 'permits descending code sorting and rejects invalid page sizes' do
    query.params = ActionController::Parameters.new(sort: 'code', direction: 'desc', per_page: '500')

    expect(query.send(:apply_sorting, Supplier.all).to_sql).to include('ORDER BY "suppliers"."code" DESC')
    expect(query.send(:per_page_param)).to eq(10)
  end

  it 'accepts supported page sizes' do
    [5, 10, 15].each do |value|
      query.params = ActionController::Parameters.new(per_page: value)
      expect(query.send(:per_page_param)).to eq(value)
    end
  end

  it 'clamps requests for pages past the final result page' do
    query.instance_variable_set(:@total_count, 14)
    query.params = ActionController::Parameters.new(page: '999', per_page: 5)

    scope = query.send(:paginate, Supplier.all)

    expect(query.instance_variable_get(:@total_pages)).to eq(3)
    expect(scope.to_sql).to include('LIMIT 5 OFFSET 10')
  end

  it 'normalizes negative page numbers to the first page' do
    query.instance_variable_set(:@total_count, 25)
    query.params = ActionController::Parameters.new(page: '-3', per_page: 5)

    scope = query.send(:paginate, Supplier.all)

    expect(scope.to_sql).to include('LIMIT 5 OFFSET 0')
  end
end
