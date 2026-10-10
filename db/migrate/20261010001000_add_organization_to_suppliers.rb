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

    # Legacy records must be explicitly assigned to an organization by an authorized
    # administrator. Never infer ownership from a user, branch or arbitrary tenant.
    add_check_constraint :suppliers, 'organization_id IS NOT NULL',
                         name: 'chk_suppliers_organization_required',
                         validate: false
  end

  def down
    remove_check_constraint :suppliers, name: 'chk_suppliers_organization_required'
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
