class CreateBranches < ActiveRecord::Migration[8.1]
  def change
    create_table :branches do |t|
      t.string :name
      t.string :phone
      t.string :address
      t.boolean :status
      t.timestamp :deleted_at

      t.timestamps
    end
    add_index :branches, :deleted_at
  end
end
