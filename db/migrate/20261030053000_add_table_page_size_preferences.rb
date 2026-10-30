# frozen_string_literal: true

class AddTablePageSizePreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_settings, :default_table_page_size, :integer, default: 10, null: false
    add_check_constraint :organization_settings,
                         'default_table_page_size IN (5, 10, 15, 25, 50)',
                         name: 'chk_organization_settings_table_page_size'

    create_table :table_page_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :table_key, null: false, limit: 70
      t.integer :per_page, null: false
      t.timestamps
    end

    add_index :table_page_preferences, %i[user_id organization_id table_key],
              unique: true, name: 'idx_table_page_preferences_owner_and_table'
    add_check_constraint :table_page_preferences, 'per_page IN (5, 10, 15, 25, 50)',
                         name: 'chk_table_page_preferences_per_page'
  end
end
