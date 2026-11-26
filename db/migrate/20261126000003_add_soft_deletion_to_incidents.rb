class AddSoftDeletionToIncidents < ActiveRecord::Migration[8.1]
  def change
    add_column :incidents, :deleted_at, :datetime
    add_column :incident_types, :deleted_at, :datetime
    add_column :incident_events, :deleted_at, :datetime
  end
end
