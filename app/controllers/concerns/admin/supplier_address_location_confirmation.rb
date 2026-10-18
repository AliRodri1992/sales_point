# frozen_string_literal: true

module Admin
  module SupplierAddressLocationConfirmation
    extend ActiveSupport::Concern

    private

    def enqueue_geocoding(address)
      return if address.location_confirmed?

      GeocodeAddressJob.perform_later(address.id, address.geocoding_fingerprint)
    end

    def apply_confirmation?
      return true unless params.dig(:address, :location_confirmed) == '1'

      coords = params.expect(address: %i[latitude longitude location_signature location_adjustment_reason])
      unless valid_location_proof?(coords)
        @address.errors.add(:base, :invalid_location_confirmation)
        return false
      end

      @address.assign_attributes(
        latitude: coords[:latitude], longitude: coords[:longitude],
        location_adjustment_reason: coords[:location_adjustment_reason].presence,
        location_confirmed_at: Time.current, geocoding_status: 'success'
      )
      true
    end

    def valid_location_proof?(coords)
      Suppliers::AddressLocationProof.verify(
        token: coords[:location_signature], address: @address, supplier: @supplier,
        user: current_user, selection: { latitude: coords[:latitude], longitude: coords[:longitude],
                                         reason: coords[:location_adjustment_reason] }
      )
    end
  end
end
