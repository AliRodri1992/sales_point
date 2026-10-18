# frozen_string_literal: true

module AddressLocation
  extend ActiveSupport::Concern

  included do
    before_validation :invalidate_stale_coordinates, on: %i[create update]
  end

  def geocoding_fingerprint
    Digest::SHA256.hexdigest(geocoding_query.downcase.squish)
  end

  def geocoding_query
    [street, exterior_number, interior_number, neighborhood, city, state,
     postal_code, country&.iso_alpha2].compact_blank.join(', ')
  end

  def location_confirmed?
    location_confirmed_at.present?
  end

  private

  def invalidate_stale_coordinates
    fields = %w[street exterior_number interior_number neighborhood city state postal_code country_id]
    return unless persisted? && fields.any? { |name| will_save_change_to_attribute?(name) }
    return if will_save_change_to_location_confirmed_at? && location_confirmed_at.present?

    self.latitude = nil
    self.longitude = nil
    self.location_confirmed_at = nil
    self.geocoding_status = 'pending'
  end
end
