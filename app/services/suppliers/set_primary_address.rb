# frozen_string_literal: true

module Suppliers
  # Switches the primary address for a single supplier/purpose atomically.
  # The supplier row lock serializes concurrent selections across address cards.
  class SetPrimaryAddress
    def initialize(supplier:, address:)
      @supplier = supplier
      @address = address
    end

    def call
      @supplier.with_lock do
        target = @supplier.addresses.not_deleted.find(@address.id)
        next false if target.primary?

        demote_previous_primary(target)
        target.update!(primary: true)
        true
      end
    end

    private

    def demote_previous_primary(target)
      @supplier.addresses.not_deleted.where(purpose: target.purpose, primary: true)
               .where.not(id: target.id).find_each do |previous|
        previous.update!(primary: false)
      end
    end
  end
end
