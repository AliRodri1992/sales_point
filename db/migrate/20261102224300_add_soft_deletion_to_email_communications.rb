# frozen_string_literal: true

class AddSoftDeletionToEmailCommunications < ActiveRecord::Migration[8.1]
  def change
    %i[email_template_versions email_template_audits email_branding_settings email_sender_settings].each do |table|
      add_column table, :deleted_at, :datetime
      add_index table, :deleted_at
    end
  end
end
