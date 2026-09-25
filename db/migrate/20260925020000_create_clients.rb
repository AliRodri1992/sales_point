class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :code, null: false, limit: 30
      t.string :name, null: false, limit: 150
      t.string :email, limit: 150
      t.string :phone, limit: 30
      t.string :rfc, limit: 13
      t.references :sat_fiscal_regime, foreign_key: true
      t.string :postal_code, limit: 5
      t.decimal :credit_limit, precision: 12, scale: 2, null: false, default: 0
      t.string :status, null: false, limit: 20, default: 'active'
      t.text :notes
      t.timestamp :deleted_at

      t.timestamps
    end

    add_index :clients, :code, unique: true, where: "deleted_at IS NULL"
    add_index :clients, :rfc, unique: true, where: "rfc IS NOT NULL AND rfc <> '' AND deleted_at IS NULL"
    add_index :clients, :email
    add_index :clients, :phone
    add_index :clients, :status
    add_index :clients, :deleted_at
  end
end
