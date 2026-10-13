# frozen_string_literal: true

class CreateSupplierFinancials < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_bank_accounts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.string :sat_bank_code, limit: 3
      t.string :bank_name, limit: 120
      t.string :holder_name, null: false, limit: 180
      t.string :account_number
      t.string :clabe
      t.string :last_four, limit: 4
      t.boolean :primary, default: false, null: false
      t.string :currency_code, limit: 3, default: 'MXN', null: false
      t.datetime :deleted_at
      t.timestamps
      t.index %i[organization_id supplier_id primary], name: 'idx_supplier_bank_accounts_org_supplier'
      t.index :deleted_at
      t.index %i[supplier_id primary], unique: true, where: 'primary = true AND deleted_at IS NULL',
              name: 'idx_supplier_one_primary_bank_account'
      t.foreign_key :sat_banks, column: :sat_bank_code, primary_key: :code
    end

    create_table :supplier_invoices do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :purchase_order, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :uuid, limit: 36
      t.string :series, limit: 30
      t.string :folio, limit: 60
      t.string :issuer_rfc, limit: 13
      t.string :receiver_rfc, limit: 13
      t.string :payment_method, limit: 3
      t.date :issued_on, null: false
      t.date :received_on, null: false
      t.date :due_on, null: false
      t.decimal :exchange_rate, precision: 18, scale: 8, default: 1, null: false
      t.decimal :subtotal, precision: 18, scale: 2, default: 0, null: false
      t.decimal :discount, precision: 18, scale: 2, default: 0, null: false
      t.decimal :tax_amount, precision: 18, scale: 2, default: 0, null: false
      t.decimal :total, precision: 18, scale: 2, null: false
      t.string :status, null: false, default: 'draft', limit: 20
      t.string :source, null: false, default: 'manual', limit: 20
      t.datetime :posted_at
      t.datetime :cancelled_at
      t.text :notes
      t.timestamps
      t.index %i[organization_id uuid], unique: true, where: 'uuid IS NOT NULL',
              name: 'idx_supplier_invoices_org_uuid'
      t.index %i[organization_id due_on status]
      t.index %i[supplier_id issued_on]
      t.check_constraint 'total >= 0 AND subtotal >= 0 AND discount >= 0 AND tax_amount >= 0 AND exchange_rate > 0',
                         name: 'chk_supplier_invoices_amounts'
    end

    create_table :supplier_invoice_lines do |t|
      t.references :supplier_invoice, null: false, foreign_key: true
      t.string :description, null: false, limit: 500
      t.decimal :quantity, precision: 18, scale: 6, null: false
      t.decimal :unit_price, precision: 18, scale: 6, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.timestamps
      t.check_constraint 'quantity > 0 AND unit_price >= 0 AND amount >= 0', name: 'chk_supplier_invoice_lines'
    end

    create_table :supplier_invoice_receipts do |t|
      t.references :supplier_invoice, null: false, foreign_key: true
      t.references :goods_receipt, null: false, foreign_key: true
      t.timestamps
      t.index %i[supplier_invoice_id goods_receipt_id], unique: true,
              name: 'idx_supplier_invoice_receipt_unique'
    end

    create_table :account_payables do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :supplier_invoice, null: false, foreign_key: true, index: { unique: true }
      t.date :due_on, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.timestamps
      t.index %i[organization_id due_on]
      t.check_constraint 'amount >= 0', name: 'chk_account_payable_amount'
    end

    create_table :supplier_payments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.references :supplier_bank_account, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.date :paid_on, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.string :reference, limit: 120
      t.string :status, default: 'draft', null: false, limit: 20
      t.datetime :posted_at
      t.datetime :reversed_at
      t.text :notes
      t.timestamps
      t.index %i[organization_id supplier_id paid_on]
      t.check_constraint 'amount > 0', name: 'chk_supplier_payment_amount'
    end

    create_table :supplier_payment_allocations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier_payment, null: false, foreign_key: true
      t.references :account_payable, null: false, foreign_key: true
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.timestamps
      t.index %i[supplier_payment_id account_payable_id], unique: true,
              name: 'idx_supplier_payment_allocation_unique'
      t.check_constraint 'amount > 0', name: 'chk_supplier_payment_allocation_amount'
    end

    create_table :supplier_credit_notes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.references :supplier_invoice, foreign_key: true
      t.references :purchase_return, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :uuid, limit: 36
      t.string :folio, limit: 60
      t.date :issued_on, null: false
      t.decimal :total, precision: 18, scale: 2, null: false
      t.string :status, default: 'draft', null: false, limit: 20
      t.text :notes
      t.timestamps
      t.index %i[organization_id uuid], unique: true, where: 'uuid IS NOT NULL',
              name: 'idx_supplier_credit_notes_org_uuid'
      t.check_constraint 'total > 0', name: 'chk_supplier_credit_note_amount'
    end

    create_table :supplier_credit_allocations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :supplier_credit_note, null: false, foreign_key: true
      t.references :account_payable, null: false, foreign_key: true
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.timestamps
      t.index %i[supplier_credit_note_id account_payable_id], unique: true,
              name: 'idx_supplier_credit_allocation_unique'
      t.check_constraint 'amount > 0', name: 'chk_supplier_credit_allocation_amount'
    end

    create_table :financial_audit_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event, null: false, limit: 80
      t.string :subject_type, null: false, limit: 80
      t.bigint :subject_id, null: false
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
      t.index %i[organization_id created_at]
      t.index %i[subject_type subject_id]
    end

    create_table :financial_reminder_deliveries do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :account_payable, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :event_key, null: false, limit: 64
      t.timestamps
      t.index :event_key, unique: true
    end
  end
end

