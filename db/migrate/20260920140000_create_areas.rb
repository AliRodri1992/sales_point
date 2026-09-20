class CreateAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :areas do |t|
      t.string :name
      t.string :code
      t.string :status

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :areas, :deleted_at
    add_index :areas, :code, unique: true, where: 'deleted_at IS NULL'
  end
end
