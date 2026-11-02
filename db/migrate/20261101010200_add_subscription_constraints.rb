# frozen_string_literal: true

class AddSubscriptionConstraints < ActiveRecord::Migration[8.1]
  def change
    add_index :subscriptions,
              :organization_id,
              unique: true,
              where: "status IN ('trialing', 'active', 'past_due', 'paused') AND deleted_at IS NULL",
              name: 'idx_subscriptions_one_current_per_organization'
  end
end
