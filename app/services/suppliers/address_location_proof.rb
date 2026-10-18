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

    def self.verify(token:, address:, supplier:, user:, selection:)
      payload = verifier.verified(token)&.symbolize_keys
      return false unless matching?(payload, address, supplier, user)

      origin = [payload.fetch(:latitude), payload.fetch(:longitude)]
      selected = [selection.fetch(:latitude), selection.fetch(:longitude)]
      distance = distance_km(origin, selected)
      return false unless distance.finite?

      distance <= MAX_ADJUSTMENT_KM || selection[:reason].to_s.strip.length.between?(10, 250)
    rescue ArgumentError, TypeError, KeyError
      false
    end

    def self.matching?(payload, address, supplier, user)
      payload.is_a?(Hash) &&
        payload[:fingerprint] == address.geocoding_fingerprint &&
        payload[:supplier_id] == supplier.id &&
        payload[:user_id] == user.id
    end

    def self.distance_km(origin, selected)
      first_lat, first_lon = origin.map { |value| Float(value) }
      second_lat, second_lon = selected.map { |value| Float(value) }
      return Float::INFINITY unless second_lat.between?(-90, 90) && second_lon.between?(-180, 180)

      factor = haversine_factor(first_lat, first_lon, second_lat, second_lon)
      2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(factor.clamp(0.0, 1.0)))
    end

    def self.haversine_factor(first_lat, first_lon, second_lat, second_lon)
      sin_lat = Math.sin(radians(second_lat - first_lat) / 2)
      sin_lon = Math.sin(radians(second_lon - first_lon) / 2)
      (sin_lat**2) + (Math.cos(radians(first_lat)) * Math.cos(radians(second_lat)) * (sin_lon**2))
    end

    def self.radians(degrees)
      degrees * Math::PI / 180
    end

    def self.verifier
      Rails.application.message_verifier('supplier-address-location-v2')
    end

    private_class_method :matching?, :distance_km, :haversine_factor, :radians, :verifier
  end
end
