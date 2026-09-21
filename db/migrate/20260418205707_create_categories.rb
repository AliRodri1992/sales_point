# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name
      t.string :code
      t.string :status

      t.timestamps
      t.timestamp :deleted_at
    end

    add_index :categories, :deleted_at
    add_index :categories, :code, unique: true, where: 'deleted_at IS NULL'
  end
end
