# frozen_string_literal: true

class CreateLandingSections < ActiveRecord::Migration[8.1]
  SECTIONS = [
    ['hero', 1],
    ['benefits', 2],
    ['modules', 3],
    ['how_it_works', 4],
    ['screenshots', 5],
    ['security', 6],
    ['testimonials', 7],
    ['faq', 8],
    ['cta', 9]
  ].freeze

  def up
    create_table :landing_sections do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false
      t.timestamps
    end

    add_index :landing_sections, :key, unique: true
    add_index :landing_sections, :position, unique: true

    SECTIONS.each do |key, position|
      execute <<~SQL.squish
        INSERT INTO landing_sections (key, enabled, position, created_at, updated_at)
        VALUES ('#{key}', TRUE, #{position}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end
  end

  def down
    drop_table :landing_sections
  end
end
