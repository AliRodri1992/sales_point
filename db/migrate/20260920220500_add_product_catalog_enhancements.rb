# frozen_string_literal: true

class AddProductCatalogEnhancements < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :position, :integer, default: 0
    add_column :products, :image_url, :string
    add_column :products, :featured, :boolean, default: false
    add_column :products, :view_count, :integer, default: 0
    add_column :products, :slug, :string

    add_index :products, :position
    add_index :products, :featured
    add_index :products, :slug, unique: true, where: '(deleted_at IS NULL)'
  end
end