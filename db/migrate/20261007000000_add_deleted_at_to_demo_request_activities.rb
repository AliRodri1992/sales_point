class AddDeletedAtToDemoRequestActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_request_activities, :deleted_at, :datetime
    add_index :demo_request_activities, :deleted_at
  end
end
