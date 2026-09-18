# frozen_string_literal: true

class CreateMembershipPlanFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_plan_features do |t|
      t.references :membership_plan, null: false, foreign_key: true
      t.references :membership_feature, null: false, foreign_key: true
      t.boolean :enabled, null: false, default: true
      t.string :value
      t.integer :limit
      t.integer :position, null: false, default: 0
      t.datetime :deleted_at

      t.timestamps
    end

    add_check_constraint :membership_plan_features,
                         '"limit" IS NULL OR "limit" >= 0',
                         name: 'chk_membership_plan_features_limit_non_negative'

    add_index :membership_plan_features,
              %i[membership_plan_id membership_feature_id],
              unique: true,
              name: 'idx_membership_plan_features_unique_pair'
    add_index :membership_plan_features, :deleted_at
  end
end
