class CreateSatFiscalRegimes < ActiveRecord::Migration[8.1]
  def change
    create_table :sat_fiscal_regimes do |t|
      t.string :code, null: false, limit: 3
      t.string :description, null: false, limit: 255

      t.string :person_type, null: false, limit: 1

      t.date :valid_from
      t.date :valid_to

      t.timestamps
      t.timestamp :deleted_at
    end

    # 🔒 CHECKS
    add_check_constraint :sat_fiscal_regimes, "person_type IN ('F','M')"
    add_check_constraint :sat_fiscal_regimes, "valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from"

    add_index :sat_fiscal_regimes, [:code, :valid_from], unique: true, where: "deleted_at IS NULL"
    add_index :sat_fiscal_regimes, :person_type, where: "deleted_at IS NULL"
    add_index :sat_fiscal_regimes, [:valid_from, :valid_to], where: "deleted_at IS NULL"
    add_index :sat_fiscal_regimes, :deleted_at
  end
end
