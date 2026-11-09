# frozen_string_literal: true

class OptimizeAdminTextSearchIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # All these columns are searched using ILIKE '%term%' by admin list filters.
  # A B-tree index cannot efficiently support those leading wildcards.
  SEARCH_COLUMNS = {
    users: %i[email username],
    email_templates: %i[key name subject],
    clients: %i[code name email rfc],
    demo_requests: %i[name email company phone],
    phones: %i[number]
  }.freeze

  def up
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    SEARCH_COLUMNS.each do |table, columns|
      columns.each do |column|
        add_index table, column, using: :gin, opclass: :gin_trgm_ops,
                  where: 'deleted_at IS NULL',
                  name: "idx_#{table}_#{column}_trgm",
                  algorithm: :concurrently, if_not_exists: true
      end
    end
  end

  def down
    SEARCH_COLUMNS.each do |table, columns|
      columns.each do |column|
        remove_index table, name: "idx_#{table}_#{column}_trgm",
                     algorithm: :concurrently, if_exists: true
      end
    end

    # Do not drop pg_trgm: other modules could use the extension.
  end
end
