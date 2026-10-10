# frozen_string_literal: true

class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.references :contactable, polymorphic: true, null: false, index: true
      t.string :name, limit: 150, null: false
      t.string :position, limit: 100
      t.string :email, limit: 150
      t.string :phone, limit: 30
      t.string :mobile_phone, limit: 30
      t.boolean :primary, default: false, null: false
      t.boolean :active, default: true, null: false
      t.text :notes
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :contacts, :deleted_at
    add_index :contacts, %i[contactable_type contactable_id],
              unique: true,
              where: 'deleted_at IS NULL AND active = TRUE AND "primary" = TRUE',
              name: 'idx_contacts_one_active_primary'
    add_check_constraint :contacts, "btrim(name) <> ''", name: 'chk_contacts_name_present'
  end
end
