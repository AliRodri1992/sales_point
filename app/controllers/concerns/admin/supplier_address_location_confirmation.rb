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

      coords = params.expect(address: %i[latitude longitude location_signature]).to_h
      signature = Rails.application.message_verifier('supplier-address-location')
                       .verified(coords['location_signature'])
      unless signature == @address.geocoding_fingerprint
        @address.errors.add(:base, :invalid_location_confirmation)
        return false
      end

      @address.assign_attributes(
        latitude: coords['latitude'], longitude: coords['longitude'],
        location_confirmed_at: Time.current, geocoding_status: 'success'
      )
      true
    end


  end
end
