# frozen_string_literal: true

class CreateOnboardingAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_audits do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false, limit: 50
      t.integer :step
      t.string :section, limit: 50
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :onboarding_audits, %i[organization_id created_at]
    add_index :onboarding_audits, %i[user_id created_at]
    add_index :onboarding_audits, :action
  end
end
