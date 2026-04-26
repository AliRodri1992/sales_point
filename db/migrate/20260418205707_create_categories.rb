class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name
      t.text :description
      t.boolean :status
      t.timestamp :deleted_at

      t.timestamps
    end
    add_index :categories, :deleted_at
  end
end
