# frozen_string_literal: true

class AddCodeToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :code, :string
    add_index :categories, :code, unique: true, where: "deleted_at IS NULL"
  end
end