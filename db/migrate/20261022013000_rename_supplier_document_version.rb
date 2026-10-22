# frozen_string_literal: true

class RenameSupplierDocumentVersion < ActiveRecord::Migration[8.1]
  def change
    rename_column :supplier_documents, :version, :revision_number
  end
end
