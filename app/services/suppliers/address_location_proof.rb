# frozen_string_literal: true

module Suppliers
  # A signed, expiring geocoding proposal, scoped to both tenant and operator.
  class AddressLocationProof
    MAX_ADJUSTMENT_KM = 2.0
    EARTH_RADIUS_KM = 6371.0

    def self.issue(address:, supplier:, user:, latitude:, longitude:)
      payload = {
        fingerprint: address.geocoding_fingerprint,
        supplier_id: supplier.id, user_id: user.id,
        latitude: Float(latitude), longitude: Float(longitude)
      }
      verifier.generate(payload, expires_in: 20.minutes)
    end

    def self.verify(token:, address:, supplier:, user:, latitude:, longitude:, reason:)
      payload = verifier.verified(token)&.symbolize_keys
      return false unless matching?(payload, address, supplier, user)

      distance = distance_km(payload.fetch(:latitude), payload.fetch(:longitude), latitude, longitude)
      return false unless distance.finite?

      distance <= MAX_ADJUSTMENT_KM || reason.to_s.strip.length.between?(10, 250)
    rescue ArgumentError, TypeError, KeyError
      false
    end

    def self.matching?(payload, address, supplier, user)
      payload.is_a?(Hash) &&
        payload[:fingerprint] == address.geocoding_fingerprint &&
        payload[:supplier_id] == supplier.id &&
        payload[:user_id] == user.id
    end

    def self.distance_km(first_lat, first_lon, second_lat, second_lon)
      lat1 = Float(first_lat)
      lon1 = Float(first_lon)
      lat2 = Float(second_lat)
      lon2 = Float(second_lon)
      return Float::INFINITY unless lat2.between?(-90, 90) && lon2.between?(-180, 180)

      delta_lat = radians(lat2 - lat1)
      delta_lon = radians(lon2 - lon1)
      a = Math.sin(delta_lat / 2)**2 +
          Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(delta_lon / 2)**2
      2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt([a, 1.0].min))
    end

    def self.radians(degrees)
      degrees * Math::PI / 180
    end

    def self.verifier
      Rails.application.message_verifier('supplier-address-location-v2')
    end

    private_class_method :matching?, :distance_km, :radians, :verifier
  end
end
