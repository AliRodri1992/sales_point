# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin partial-text search indexes', type: :model do
  SEARCH_COLUMNS = {
    users: %i[email username],
    email_templates: %i[key name subject],
    clients: %i[code name email rfc],
    demo_requests: %i[name email company phone],
    phones: %i[number]
  }.freeze

  it 'enables PostgreSQL trigram matching' do
    expect(ActiveRecord::Base.connection.extension_enabled?('pg_trgm')).to be(true)
  end

  SEARCH_COLUMNS.each do |table, columns|
    columns.each do |column|
      it "indexes #{table}.#{column} for substring searches of non-deleted records" do
        index_name = "idx_#{table}_#{column}_trgm"
        index = ActiveRecord::Base.connection.indexes(table).find { |entry| entry.name == index_name }

        expect(index).to be_present
        expect(index.columns).to eq([column.to_s])
        expect(index.using.to_s).to eq('gin')
        expect(index.where).to include('deleted_at IS NULL')
      end
    end
  end
end
