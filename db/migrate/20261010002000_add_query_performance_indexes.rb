# frozen_string_literal: true

# Composite indexes for common active-record listings and notification feeds.
# Existing historical tables are optimized in a separate migration so their
# original migration history remains intact.
class AddQueryPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :addresses, %i[addressable_type addressable_id],
              where: 'deleted_at IS NULL',
              name: 'idx_addresses_owner_active'

    add_index :demo_requests, %i[status created_at],
              where: 'deleted_at IS NULL',
              name: 'idx_demo_requests_status_created_active'
    add_index :demo_requests, %i[assigned_to_id next_follow_up_at],
              where: 'deleted_at IS NULL AND next_follow_up_at IS NOT NULL',
              name: 'idx_demo_requests_assignee_follow_up_active'

    add_index :noticed_notifications, %i[recipient_type recipient_id created_at],
              order: { created_at: :desc },
              name: 'idx_noticed_notifications_recipient_recent'
    add_index :noticed_notifications, %i[recipient_type recipient_id created_at],
              where: 'read_at IS NULL',
              order: { created_at: :desc },
              name: 'idx_noticed_notifications_unread_recent'
  end
end
