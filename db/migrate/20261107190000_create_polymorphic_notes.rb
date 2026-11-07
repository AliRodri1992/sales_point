# frozen_string_literal: true

class CreatePolymorphicNotes < ActiveRecord::Migration[8.1]
  # Preserve notes before forms begin writing through the polymorphic association.
  # Existing columns are retained temporarily for code paths that still read them.
  SOURCES = [
    ['branches', 'Branch', 'base.organization_id', ''],
    ['clients', 'Client', 'NULL', ''],
    ['contacts', 'Contact', "CASE WHEN base.contactable_type = 'Organization' THEN base.contactable_id ELSE supplier.organization_id END",
     "LEFT JOIN suppliers supplier ON base.contactable_type = 'Supplier' AND supplier.id = base.contactable_id"],
    ['goods_receipts', 'GoodsReceipt', 'base.organization_id', ''],
    ['goods_receipt_items', 'GoodsReceiptItem', 'receipt.organization_id',
     'LEFT JOIN goods_receipts receipt ON receipt.id = base.goods_receipt_id'],
    ['purchase_approvals', 'PurchaseApproval', 'base.organization_id', ''],
    ['purchase_orders', 'PurchaseOrder', 'base.organization_id', ''],
    ['purchase_quotations', 'PurchaseQuotation', 'base.organization_id', ''],
    ['purchase_requests', 'PurchaseRequest', 'base.organization_id', ''],
    ['purchase_request_items', 'PurchaseRequestItem', 'request.organization_id',
     'LEFT JOIN purchase_requests request ON request.id = base.purchase_request_id'],
    ['purchase_returns', 'PurchaseReturn', 'base.organization_id', ''],
    ['purchase_return_items', 'PurchaseReturnItem', 'returned.organization_id',
     'LEFT JOIN purchase_returns returned ON returned.id = base.purchase_return_id'],
    ['supplier_credit_notes', 'SupplierCreditNote', 'base.organization_id', ''],
    ['supplier_events', 'SupplierEvent', 'supplier.organization_id',
     'LEFT JOIN suppliers supplier ON supplier.id = base.supplier_id'],
    ['supplier_invoices', 'SupplierInvoice', 'base.organization_id', ''],
    ['supplier_payments', 'SupplierPayment', 'base.organization_id', ''],
    ['supplier_schedules', 'SupplierSchedule', 'supplier.organization_id',
     'LEFT JOIN suppliers supplier ON supplier.id = base.supplier_id'],
    ['supplier_schedule_exceptions', 'SupplierScheduleException', 'supplier.organization_id',
     'LEFT JOIN suppliers supplier ON supplier.id = base.supplier_id'],
    ['suppliers', 'Supplier', 'base.organization_id', '']
  ].freeze

  def up
    create_table :notes do |t|
      t.references :notable, polymorphic: true, null: false, index: false
      t.references :organization, null: true, foreign_key: true, index: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }, index: true
      t.string :kind, limit: 30, default: 'general', null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :notes, %i[notable_type notable_id kind], unique: true, name: 'idx_notes_notable_kind'
    add_index :notes, %i[organization_id created_at], name: 'idx_notes_org_created_at'
    add_check_constraint :notes, "length(btrim(body)) > 0", name: 'chk_notes_nonempty_body'

    backfill_legacy_notes
  end

  def backfill_legacy_notes
    SOURCES.each do |table, type, organization, joins|
      execute <<~SQL.squish
        INSERT INTO notes (notable_type, notable_id, organization_id, kind, body, created_at, updated_at)
        SELECT #{connection.quote(type)}, base.id, #{organization}, 'general',
               btrim(base.notes), COALESCE(base.updated_at, CURRENT_TIMESTAMP),
               COALESCE(base.updated_at, CURRENT_TIMESTAMP)
        FROM #{connection.quote_table_name(table)} base
        #{joins}
        WHERE base.notes IS NOT NULL AND length(btrim(base.notes)) > 0
        ON CONFLICT (notable_type, notable_id, kind) DO NOTHING
      SQL
    end
  end

  def down
    drop_table :notes
  end
end
