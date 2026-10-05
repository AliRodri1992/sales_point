# frozen_string_literal: true

class AddIndexesToCategoriesAndLanguages < ActiveRecord::Migration[8.1]
  def change
    add_index :categories, :name, where: 'deleted_at IS NULL'
    add_index :languages, :name, where: 'deleted_at IS NULL'
  end
end