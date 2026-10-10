# frozen_string_literal: true

class AddOrganizationToSuppliers < ActiveRecord::Migration[8.1]
  def up
    add_reference :suppliers, :organization, null: true, foreign_key: true, index: true

    # This project uses disposable development data. Assign legacy sample suppliers
    # to an explicit demo tenant before enforcing the new required relationship.
    if select_value('SELECT EXISTS (SELECT 1 FROM suppliers WHERE organization_id IS NULL)')
      demo_id = select_value(<<~SQL)
        SELECT id FROM organizations
        WHERE tax_id = 'DPO260101AB1' AND deleted_at IS NULL
        LIMIT 1
      SQL

      unless demo_id
        demo_id = select_value(<<~SQL)
          INSERT INTO organizations
            (name, tax_id, business_sector, status, onboarding_status,
             onboarding_current_step, created_at, updated_at)
          VALUES
            ('Delta POS Demo', 'DPO260101AB1', 'grocery', 'active',
             'pending', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          RETURNING id
        SQL
      end

      execute "UPDATE suppliers SET organization_id = #{Integer(demo_id)} WHERE organization_id IS NULL"
    end

    change_column_null :suppliers, :organization_id, false

    remove_index :suppliers, name: 'index_suppliers_on_code'
    remove_index :suppliers, name: 'index_suppliers_on_rfc'

    add_index :suppliers, %i[organization_id code],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_suppliers_organization_code_active'
    add_index :suppliers, %i[organization_id rfc],
              unique: true, where: "rfc IS NOT NULL AND rfc <> '' AND deleted_at IS NULL",
              name: 'idx_suppliers_organization_rfc_active'
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
