# frozen_string_literal: true

module Suppliers
  # Serializes every supplier address save with the primary-selection action.
  # If validation fails, PostgreSQL rolls back the demotion as well.
  class SaveAddress
    def initialize(supplier:, address:)
      @supplier = supplier
      @address = address
    end

    def call
      @supplier.with_lock do
        Suppliers::SetPrimaryAddress.demote_previous_primary(supplier: @supplier, target: @address) if @address.primary?
        @address.save!
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
