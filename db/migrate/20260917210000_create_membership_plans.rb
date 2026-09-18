# frozen_string_literal: true

class CreateMembershipPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_plans do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: 'MXN', limit: 3
      t.string :billing_interval, null: false, default: 'monthly'
      t.integer :trial_days, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_check_constraint :membership_plans,
                         'price >= 0',
                         name: 'chk_membership_plans_price_non_negative'
    add_check_constraint :membership_plans,
                         "billing_interval IN ('monthly','yearly')",
                         name: 'chk_membership_plans_billing_interval'
    add_check_constraint :membership_plans,
                         'trial_days >= 0',
                         name: 'chk_membership_plans_trial_days_non_negative'

    add_index :membership_plans, :slug, unique: true
    add_index :membership_plans, %i[active position]
    add_index :membership_plans, :deleted_at
  end
end
