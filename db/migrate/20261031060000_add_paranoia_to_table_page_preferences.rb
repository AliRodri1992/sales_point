# frozen_string_literal: true

class AddParanoiaToTablePagePreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :table_page_preferences, :deleted_at, :datetime

    add_index :table_page_preferences, :deleted_at,
              name: 'index_table_page_preferences_on_deleted_at'

    remove_index :table_page_preferences, name: 'idx_table_page_preferences_owner_and_table'
    add_index :table_page_preferences, %i[user_id organization_id table_key],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_table_page_preferences_owner_and_table'
  end
end
