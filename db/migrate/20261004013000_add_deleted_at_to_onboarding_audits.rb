# frozen_string_literal: true

class AddDeletedAtToOnboardingAudits < ActiveRecord::Migration[8.1]
  def change
    add_column :onboarding_audits, :deleted_at, :timestamp
    add_index :onboarding_audits, :deleted_at
  end
end
