class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages do |t|
      t.string :code
      t.string :name
      t.string :flag_iso
      t.string :status

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :languages, :deleted_at
  end
end
