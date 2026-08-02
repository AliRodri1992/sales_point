# frozen_string_literal: true

class AddLanguageIdToTranslates < ActiveRecord::Migration[8.1]
  def change
    # Add language_id foreign key
    add_reference :translates,
                  :language,
                  foreign_key: true,
                  null: true,
                  index: true

    # Migrate existing locale strings to language_id
    reversible do |dir|
      dir.up do
        Language.find_each do |language|
          Translate.where(locale: language.code).update_all(language_id: language.id)
        end
      end
    end

    # Change locale column to be derived from language, not required
    change_column_null :translates, :locale, true
    change_column_default :translates, :locale, nil

    # Add index on language_id and locale together
    add_index :translates, [:language_id, :key], unique: true, where: 'deleted_at IS NULL'
  end
end
