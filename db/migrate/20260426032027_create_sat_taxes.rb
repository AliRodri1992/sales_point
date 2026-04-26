class CreateSatTaxes < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_taxes do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.string :tax_type, null: false, default: 'transfer'
      t.string :factor_type, null: false, default: 'rate'

      t.string :description, limit: 255
      t.string :applies_to

      t.integer :priority, null: false, default: 1

      t.boolean :is_retainable, default: false
      t.boolean :is_transferrable, default: true

      t.date :valid_from
      t.date :valid_to

      t.boolean :status, default: true

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :sat_taxes,
              "LOWER(TRIM(code))",
              unique: true,
              where: "deleted_at IS NULL"

    add_index :sat_taxes, :status
    add_index :sat_taxes, :tax_type
    add_index :sat_taxes, :factor_type
    add_index :sat_taxes, :applies_to

    add_index :sat_taxes, [:status, :deleted_at]

    add_index :sat_taxes, [:valid_from, :valid_to], where: "deleted_at IS NULL"

    add_check_constraint :sat_taxes, "tax_type IN ('transfer','withheld')"
    add_check_constraint :sat_taxes, "factor_type IN ('rate','quota','exempt')"
    add_check_constraint :sat_taxes, "applies_to IN ('product','service','both') OR applies_to IS NULL"
    add_check_constraint :sat_taxes, "(valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)"
    add_check_constraint :sat_taxes, "(tax_type = 'transfer' AND is_transferrable = TRUE) OR (tax_type = 'withheld' AND is_retainable = TRUE)"
  end
end
