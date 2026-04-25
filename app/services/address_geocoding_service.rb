class AddressGeocodingService
  def initialize(address_id)
    @address = Address.find(address_id)
  end

  def call
    return unless address

    result = geocode_address
    return unless valid_result?(result)

    update_address(result)
  rescue StandardError => e
    log_error(e)
    mark_as_failed
  end

  private

  attr_reader :address

  def geocode_address
    Geocoding::GeocodePostalCodeService
      .new(address.postal_code, address.country)
      .call
  end

  def valid_result?(result)
    result.present? && result[:lat].present? && result[:lng].present?
  end

  def update_address(result)
    address.update!(
      latitude: result[:lat],
      longitude: result[:lng],
      geocoding_status: 'success'
    )
  end

  def mark_as_failed
    address.update!(
      geocoding_status: 'failed'
    )
  end

  def log_error(error)
    Rails.logger.error(
      "[AddressGeocodingService] #{error.class}: #{error.message}"
    )
  end
end
