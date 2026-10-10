class CreateDemoRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :company, null: false
      t.text :message
      t.string :status, null: false, default: 'pending'
      t.timestamp :deleted_at

      t.timestamps
    end

    add_index :demo_requests, %i[status created_at],
              where: 'deleted_at IS NULL',
              name: 'idx_demo_requests_status_created_active'
    add_index :demo_requests, :email
    add_index :demo_requests, :status
    add_index :demo_requests, :deleted_at
  end
end
