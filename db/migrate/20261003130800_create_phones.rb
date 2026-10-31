# frozen_string_literal: true

class CreatePhones < ActiveRecord::Migration[8.1]
  def change
    create_table :phones do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :phoneable, polymorphic: true, null: false, index: true
      t.string :number, limit: 16, null: false
      t.string :country_code, limit: 2, null: false, default: 'MX'
      t.string :kind, limit: 12, null: false
      t.string :label, limit: 60
      t.string :extension, limit: 10
      t.boolean :primary, null: false, default: false
      t.boolean :whatsapp_enabled, null: false, default: false
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :phones, %i[phoneable_type phoneable_id kind],
              unique: true, where: 'deleted_at IS NULL AND "primary" = TRUE',
              name: 'idx_phones_one_primary_per_kind'
    add_index :phones, %i[phoneable_type phoneable_id number extension],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_phones_unique_active_number'
    add_index :phones, :deleted_at
    add_check_constraint :phones, "kind IN ('mobile', 'landline', 'other')",
                         name: 'chk_phones_kind'
    add_check_constraint :phones, "number ~ '^\\+[1-9][0-9]{1,14}$'",
                         name: 'chk_phones_e164'
    add_check_constraint :phones, "country_code ~ '^[A-Z]{2}$'",
                         name: 'chk_phones_country'
  end
end
