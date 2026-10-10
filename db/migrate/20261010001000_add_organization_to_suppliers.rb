# frozen_string_literal: true

class AddOrganizationToSuppliers < ActiveRecord::Migration[8.1]
  def up
    add_reference :suppliers, :organization, null: true, foreign_key: true, index: true

    remove_index :suppliers, name: 'index_suppliers_on_code'
    remove_index :suppliers, name: 'index_suppliers_on_rfc'

    add_index :suppliers, %i[organization_id code],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_suppliers_organization_code_active'
    add_index :suppliers, %i[organization_id rfc],
              unique: true, where: "rfc IS NOT NULL AND rfc <> '' AND deleted_at IS NULL",
              name: 'idx_suppliers_organization_rfc_active'

    # Existing suppliers remain unassigned until ownership is reconciled.
  end

  def down
    remove_index :suppliers, name: 'idx_suppliers_organization_rfc_active'
    remove_index :suppliers, name: 'idx_suppliers_organization_code_active'
    remove_reference :suppliers, :organization, foreign_key: true, index: true

    add_index :suppliers, :code, unique: true,
              where: 'deleted_at IS NULL', name: 'index_suppliers_on_code'
    add_index :suppliers, :rfc, unique: true,
              where: "rfc IS NOT NULL AND rfc <> '' AND deleted_at IS NULL",
              name: 'index_suppliers_on_rfc'
  end
end
