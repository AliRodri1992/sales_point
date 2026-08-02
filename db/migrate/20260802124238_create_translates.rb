# frozen_string_literal: true

class CreateTranslates < ActiveRecord::Migration[8.1]
  def change
    create_table :translates do |t|
      t.string :key, null: false, limit: 255
      t.text :value, null: false
      t.string :locale, null: false, limit: 10, default: 'en'
      t.datetime :deleted_at, index: true

      t.timestamps
    end

    # Add indexes for common queries
    add_index :translates, :key
    add_index :translates, :locale
    add_index :translates, [:key, :locale], unique: true, where: 'deleted_at IS NULL'
  end
end
