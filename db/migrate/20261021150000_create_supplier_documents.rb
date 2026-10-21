# frozen_string_literal: true

class CreateSupplierDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_documents do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :attachment, null: false, foreign_key: { to_table: :active_storage_attachments },
                                index: { unique: true }
      t.references :previous_version, foreign_key: { to_table: :supplier_documents }
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.string :series_id, null: false
      t.integer :version, null: false, default: 1
      t.boolean :current_version, null: false, default: true
      t.string :category, null: false, default: 'other'
      t.string :status, null: false, default: 'active'
      t.string :description, limit: 300
      t.timestamp :deleted_at
      t.timestamps
    end
    add_index :supplier_documents, %i[supplier_id series_id version], unique: true,
              name: 'idx_supplier_document_version'
    add_index :supplier_documents, %i[supplier_id current_version deleted_at],
              name: 'idx_supplier_document_listing'
  end
end
