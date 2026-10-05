# frozen_string_literal: true

class CreatePaymentIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_integrations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :provider, null: false, limit: 30
      t.string :status, null: false, default: 'pending', limit: 20
      t.jsonb :configuration, null: false, default: {}
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :payment_integrations, :deleted_at
    add_index :payment_integrations, [:organization_id, :provider], unique: true,
              where: 'deleted_at IS NULL', name: 'idx_payment_integrations_org_provider_active'
    add_check_constraint :payment_integrations,
                         "provider IN ('card', 'qr')",
                         name: 'check_payment_integrations_provider'
    add_check_constraint :payment_integrations,
                         "status IN ('pending', 'active', 'inactive')",
                         name: 'check_payment_integrations_status'
  end
end