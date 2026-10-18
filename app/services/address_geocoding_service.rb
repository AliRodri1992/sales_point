# frozen_string_literal: true

class AddressGeocodingService
  def initialize(address_id, fingerprint = nil)
    @address = Address.find(address_id)
    @fingerprint = fingerprint
  end

  def call
    return unless eligible?

    result = Geocoding::MapboxValidateAddressService.new(@address).call
    return mark_as_failed unless result[:valid]

    @address.with_lock do
      next unless eligible?

      @address.update!(
        latitude: result[:latitude], longitude: result[:longitude],
        geocoding_status: 'success', location_confirmed_at: nil
      )
    end
  rescue Faraday::Error, StandardError => e
    Rails.logger.error("[AddressGeocodingService] #{e.class}: #{e.message}")
    mark_as_failed
  end

  private

  def eligible?
    !@address.location_confirmed? &&
      (@fingerprint.nil? || @address.geocoding_fingerprint == @fingerprint)
  end

  def mark_as_failed
    @address.with_lock do
      @address.update!(geocoding_status: 'failed') if eligible?
    end
  end
end
