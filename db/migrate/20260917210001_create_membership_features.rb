# frozen_string_literal: true

class CreateMembershipFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_features do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :description
      t.string :value_type, null: false, default: 'boolean'
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_check_constraint :membership_features,
                         "value_type IN ('boolean','integer','decimal','text')",
                         name: 'chk_membership_features_value_type'

    add_index :membership_features, :key, unique: true
    add_index :membership_features, %i[active position]
    add_index :membership_features, :deleted_at
  end
end
