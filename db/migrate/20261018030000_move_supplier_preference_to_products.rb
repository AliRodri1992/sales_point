# frozen_string_literal: true

class MoveSupplierPreferenceToProducts < ActiveRecord::Migration[8.1]
  def up
    add_reference :products, :preferred_supplier, foreign_key: { to_table: :suppliers }, index: true

    # Preserve only existing preferences with a live supplier and active offer.
    execute <<~SQL
      UPDATE products AS product
      SET preferred_supplier_id = offer.supplier_id
      FROM supplier_products AS offer
      INNER JOIN suppliers AS supplier ON supplier.id = offer.supplier_id
      WHERE offer.product_id = product.id
        AND offer.organization_id = product.organization_id
        AND supplier.organization_id = product.organization_id
        AND offer.preferred = TRUE
        AND offer.active = TRUE
        AND offer.deleted_at IS NULL
        AND supplier.deleted_at IS NULL
        AND supplier.status = 'active'
    SQL

    remove_index :supplier_products, name: 'idx_supplier_products_one_preferred'
    remove_column :supplier_products, :preferred
  end

  def down
    add_column :supplier_products, :preferred, :boolean, default: false, null: false
    execute <<~SQL
      UPDATE supplier_products AS offer
      SET preferred = TRUE
      FROM products AS product
      WHERE offer.product_id = product.id
        AND offer.supplier_id = product.preferred_supplier_id
        AND offer.id = (
          SELECT MIN(candidate.id)
          FROM supplier_products AS candidate
          WHERE candidate.product_id = offer.product_id
            AND candidate.supplier_id = offer.supplier_id
            AND candidate.active = TRUE
            AND candidate.deleted_at IS NULL
        )
    SQL
    add_index :supplier_products, %i[organization_id product_id], unique: true,
              where: 'preferred = TRUE AND deleted_at IS NULL', name: 'idx_supplier_products_one_preferred'
    remove_reference :products, :preferred_supplier, foreign_key: { to_table: :suppliers }, index: true
  end
end
