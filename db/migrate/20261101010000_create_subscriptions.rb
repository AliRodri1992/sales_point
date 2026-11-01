# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :membership_plan, null: false, foreign_key: true
      t.string :status, limit: 20, null: false, default: 'active'
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.datetime :trial_ends_at
      t.datetime :canceled_at
      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, [:organization_id, :status],
              name: 'idx_subscriptions_organization_status'
    add_check_constraint :subscriptions,
                         "status IN ('trialing', 'active', 'past_due', 'paused', 'canceled', 'expired')",
                         name: 'chk_subscriptions_status'
    add_check_constraint :subscriptions,
                         'ends_at IS NULL OR ends_at >= starts_at',
                         name: 'chk_subscriptions_end_after_start'
    add_check_constraint :subscriptions,
                         'trial_ends_at IS NULL OR trial_ends_at >= starts_at',
                         name: 'chk_subscriptions_trial_after_start'
  end
end
