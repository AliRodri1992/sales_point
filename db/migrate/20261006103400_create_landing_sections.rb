# frozen_string_literal: true

class CreateLandingSections < ActiveRecord::Migration[8.1]
  def change
    create_table :landing_sections do |t|
      t.string :key, null: false
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :landing_sections, :key, unique: true
    add_index :landing_sections, :position, unique: true
    add_index :landing_sections, :enabled
  end
end
