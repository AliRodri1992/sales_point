class CreateDashboardPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_preferences do |t|
      t.references :user, null: false, foreign_key: true

      t.string :grid_type, null: false
      t.string :widget_id, null: false

      t.integer :position_x, null: false, default: 0
      t.integer :position_y, null: false, default: 0
      t.integer :width, null: false, default: 1
      t.integer :height, null: false, default: 1

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :dashboard_preferences, [:user_id, :widget_id], unique: true
    add_index :dashboard_preferences, :deleted_at
  end
end
