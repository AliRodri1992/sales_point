# frozen_string_literal: true

class AddSupplierAddressLocationReview < ActiveRecord::Migration[8.1]
  def change
    add_column :addresses, :location_adjustment_reason, :string, limit: 250
    add_column :addresses, :geocoding_confidence, :decimal, precision: 4, scale: 3
  end
end
