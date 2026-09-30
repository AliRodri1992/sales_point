# frozen_string_literal: true

class AddTranslationGenerationTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :languages, :locale, :string, limit: 20
    add_index :languages, :locale, unique: true, where: 'deleted_at IS NULL'

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE languages
          SET locale = code
          WHERE locale IS NULL
        SQL
      end
    end

    change_column_null :languages, :locale, false

    create_table :translation_generations do |t|
      t.references :language, null: false, foreign_key: true
      t.references :source_language, foreign_key: { to_table: :languages }, null: true
      t.references :actor, foreign_key: { to_table: :users }, null: true
      t.string :provider, null: false, limit: 100
      t.string :provider_configuration_version, null: false, limit: 64
      t.string :status, null: false, default: 'pending', limit: 20
      t.integer :total_translations, null: false, default: 0
      t.integer :completed_translations, null: false, default: 0
      t.integer :failed_translations, null: false, default: 0
      t.integer :skipped_translations, null: false, default: 0
      t.integer :deduplicated_translations, null: false, default: 0
      t.integer :retry_count, null: false, default: 0
      t.string :source_catalog_version, null: false, limit: 128
      t.text :last_error
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :translation_generations, %i[language_id source_catalog_version],
              unique: true,
              where: "status IN ('pending', 'processing')",
              name: 'index_translation_generations_on_active_catalog'
    add_index :translation_generations, :status
    add_index :translation_generations, :created_at

    add_reference :translates, :translation_generation,
                  foreign_key: true, null: true, index: true
    add_column :translates, :source_text_when_translated, :text
    add_column :translates, :source_text_digest, :string, limit: 64
    add_column :translates, :translation_source, :string, null: false, default: 'manual', limit: 20
    add_column :translates, :stale_at, :datetime
    add_index :translates, :source_text_digest
    add_index :translates, :translation_source
    add_index :translates, :stale_at
  end
end
