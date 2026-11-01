# frozen_string_literal: true

class AddOnboardingStateToOrganizations < ActiveRecord::Migration[8.1]
  def change
    change_table :organizations, bulk: true do |t|
      t.string :onboarding_status, null: false, default: 'pending', limit: 20
      t.integer :onboarding_current_step, null: false, default: 1
      t.jsonb :onboarding_sections, null: false, default: {}
      t.datetime :onboarding_completed_at
    end

    add_index :organizations, :onboarding_status
    add_check_constraint :organizations,
                         "onboarding_current_step BETWEEN 1 AND 5",
                         name: "check_organizations_onboarding_current_step"
    add_check_constraint :organizations,
                         "onboarding_status IN ('pending', 'in_progress', 'completed')",
                         name: "check_organizations_onboarding_status"
  end
end
