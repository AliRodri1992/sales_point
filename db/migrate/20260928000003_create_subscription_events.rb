# frozen_string_literal: true

class CreateSubscriptionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_events do |t|
      t.references :subscription, null: false, foreign_key: true
      t.references :membership_plan, foreign_key: true
      t.string :event_type, limit: 40, null: false
      t.string :from_status, limit: 20
      t.string :to_status, limit: 20
      t.bigint :from_membership_plan_id
      t.bigint :to_membership_plan_id
      t.bigint :performed_by_id
      t.text :description
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_foreign_key :subscription_events, :membership_plans,
                    column: :from_membership_plan_id
    add_foreign_key :subscription_events, :membership_plans,
                    column: :to_membership_plan_id
    add_foreign_key :subscription_events, :users,
                    column: :performed_by_id

    add_index :subscription_events, :event_type
    add_index :subscription_events, :performed_by_id
    add_index :subscription_events, :from_membership_plan_id
    add_index :subscription_events, :to_membership_plan_id

    add_check_constraint :subscription_events,
                         "event_type IN ('subscription_created', 'subscription_updated', 'trial_started', 'trial_ended', 'plan_changed', 'paused', 'resumed', 'canceled', 'expired')",
                         name: 'chk_subscription_events_event_type'
  end
end
