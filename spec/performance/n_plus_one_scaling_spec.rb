# frozen_string_literal: true

require 'rails_helper'

# Guards the paginated catalog queries at realistic collection sizes.
# Queries are observed only during the HTTP request, not fixture creation.
RSpec.describe 'N+1 query scaling for administrative catalogs', type: :request, n_plus_one: true do
  include SqlQueryRecorder

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def query_counts_for(record_sizes, path, pattern)
    counts = {}
    previous_size = 0

    record_sizes.each do |size|
      (size - previous_size).times { |index| yield(previous_size + index) }
      sql = recorded_sql_queries { get path, params: { per_page: 50 } }

      expect(response).to have_http_status(:ok)
      counts[size] = sql.grep(pattern).size
      previous_size = size
    end

    RSpec.configuration.reporter.message("N+1 scaling SQL counts for #{path}: #{counts.inspect}")
    counts
  end

  def expect_bounded_query_growth(counts, limit:)
    expect(counts.keys).to eq([1, 20, 100])
    expect(counts.fetch(1)).to be >= 1
    expect(counts.values.max).to be <= limit
    expect(counts.fetch(100)).to be <= counts.fetch(1) + 1
  end

  it 'does not multiply inventory stock aggregations across 1, 20, and 100 products' do
    counts = query_counts_for([1, 20, 100], admin_products_path, /SUM\([^\n]*stock[^\n]*\)/i) do |index|
      create(:product, organization:, name: "Measured product #{index}")
    end

    expect_bounded_query_growth(counts, limit: 1)
  end

  it 'does not multiply phone queries across 1, 20, and 100 clients' do
    counts = query_counts_for([1, 20, 100], admin_clients_path, /FROM\s+"?phones"?/i) do |_index|
      create(:client)
    end

    expect_bounded_query_growth(counts, limit: 2)
  end

  it 'does not multiply phone queries across 1, 20, and 100 branches' do
    counts = query_counts_for([1, 20, 100], admin_branches_path, /FROM\s+"?phones"?/i) do |index|
      create(:branch, organization:, name: "Measured branch #{index}")
    end

    expect_bounded_query_growth(counts, limit: 2)
  end
end
