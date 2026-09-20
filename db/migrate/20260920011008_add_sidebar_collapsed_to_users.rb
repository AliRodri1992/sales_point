class AddSidebarCollapsedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :sidebar_collapsed, :boolean, default: false, null: false
  end
end
