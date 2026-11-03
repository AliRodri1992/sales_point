# frozen_string_literal: true

class AddInvitationDeliveryTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :user_invitations, :delivery_status, :string, null: false, default: 'pending'
    add_column :user_invitations, :delivery_attempted_at, :datetime
    add_column :user_invitations, :sent_at, :datetime
    add_index :user_invitations, [:delivery_status, :created_at],
              where: 'accepted_at IS NULL AND revoked_at IS NULL AND deleted_at IS NULL',
              name: 'idx_user_invitations_delivery_queue'
    add_check_constraint :user_invitations,
                         "delivery_status IN ('pending','queued','sent','failed')",
                         name: 'chk_user_invitations_delivery_status'
  end
end
