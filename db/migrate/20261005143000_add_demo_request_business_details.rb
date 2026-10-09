class AddDemoRequestBusinessDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :business_type, :string, limit: 30
    add_column :demo_requests, :branches, :integer, null: false, default: 1
    add_column :demo_requests, :terms_accepted, :boolean, null: false, default: false
    add_column :demo_requests, :terms_accepted_at, :datetime

    add_index :demo_requests, :business_type
    add_index :demo_requests, :branches
    add_index :demo_requests, :terms_accepted
  end
end
