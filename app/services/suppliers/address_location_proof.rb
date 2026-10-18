# frozen_string_literal: true

module Suppliers
  # A tenant- and user-scoped, expiring proposal. The server (not JavaScript)
  # decides whether an adjusted/low-confidence position can be confirmed.
  class AddressLocationProof
    MAX_ADJUSTMENT_KM = 2.0
    HARD_LIMIT_KM = 25.0
    MIN_CONFIDENCE = 0.8
    EARTH_RADIUS_KM = 6371.0

    def self.issue(address:, supplier:, user:, coordinates:)
      payload = {
        fingerprint: address.geocoding_fingerprint,
        supplier_id: supplier.id, user_id: user.id,
        latitude: Float(coordinates.fetch(:latitude)), longitude: Float(coordinates.fetch(:longitude)),
        confidence: Float(coordinates.fetch(:confidence, 1.0) || 0)
      }
      verifier.generate(payload, expires_in: 20.minutes)
    end

    def self.verify(token:, address:, supplier:, user:, selection:)
      proposal = verified_proposal(token:, address:, supplier:, user:)
      return false unless proposal

      origin = proposal.values_at(:latitude, :longitude)
      point = selection.values_at(:latitude, :longitude)
      distance = distance_km(origin, point)
      return false unless distance.finite? && distance <= HARD_LIMIT_KM

      return true unless review_required?(proposal, distance)

      selection[:reviewed].to_s == '1' && valid_reason?(selection[:reason])
    rescue ArgumentError, TypeError, KeyError
      false
    end

    def self.confidence(token:, address:, supplier:, user:)
      verified_proposal(token:, address:, supplier:, user:)&.fetch(:confidence)
    end

    def self.review_required?(proposal, distance)
      proposal.fetch(:confidence) < MIN_CONFIDENCE || distance > MAX_ADJUSTMENT_KM
    end

    def self.valid_reason?(reason)
      reason.to_s.strip.length.between?(10, 250)
    end

    def self.verified_proposal(token:, address:, supplier:, user:)
      payload = verifier.verified(token)&.symbolize_keys
      return unless payload.is_a?(Hash)
      return unless payload[:fingerprint] == address.geocoding_fingerprint
      return unless payload[:supplier_id] == supplier.id && payload[:user_id] == user.id

      confidence = Float(payload.fetch(:confidence))
      return unless confidence.between?(0, 1)

      payload
    rescue ArgumentError, TypeError, KeyError
      nil
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
      Rails.application.message_verifier('supplier-address-location-v3')
    end

    private_class_method :verified_proposal, :review_required?, :valid_reason?,
                         :distance_km, :haversine_factor, :radians, :verifier
  end
end
