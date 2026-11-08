# frozen_string_literal: true

class CreatePolymorphicNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :notable, polymorphic: true, null: false, index: false
      t.references :organization, null: true, foreign_key: true, index: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }, index: true
      t.string :kind, limit: 30, default: 'general', null: false
      t.text :body, null: false
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :notes, %i[notable_type notable_id kind], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_notes_notable_kind'
    add_index :notes, :deleted_at
    add_index :notes, %i[organization_id created_at], name: 'idx_notes_org_created_at'
    add_check_constraint :notes, "length(btrim(body)) > 0", name: 'chk_notes_nonempty_body'
  end
end
