class AddDemoRequestWorkflow < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :assigned_to_id, :bigint
    add_index :demo_requests, :assigned_to_id

    add_foreign_key :demo_requests, :users, column: :assigned_to_id

    change_column_default :demo_requests, :status, from: 'pending', to: 'pending'

    create_table :demo_request_activities do |t|
      t.references :demo_request, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false
      t.text :details
      t.timestamps
    end

    add_index :demo_request_activities, :action
  end
end
