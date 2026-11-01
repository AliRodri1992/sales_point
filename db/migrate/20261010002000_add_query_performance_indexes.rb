# frozen_string_literal: true

# next_follow_up_at is introduced after CreateDemoRequests, so its index
# must be created only after that column exists.
class AddQueryPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :demo_requests, %i[assigned_to_id next_follow_up_at],
              where: 'deleted_at IS NULL AND next_follow_up_at IS NOT NULL',
              name: 'idx_demo_requests_assignee_follow_up_active'
  end
end
