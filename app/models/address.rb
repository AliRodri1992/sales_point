class Address < ApplicationRecord
  enum :geocoding_status, {
    pending: 'pending',
    success: 'success',
    failed: 'failed'
  }

  validates :country, presence: true, length: { maximum: 100 }
  validates :postal_code, presence: true, length: { maximum: 10 }

  validates :latitude,
            numericality: {
              greater_than_or_equal_to: -90,
              less_than_or_equal_to: 90
            },
            allow_nil: true

  validates :longitude,
            numericality: {
              greater_than_or_equal_to: -180,
              less_than_or_equal_to: 180
            },
            allow_nil: true

  scope :active, -> { where(deleted_at: nil) }

  scope :geocoded, -> { where(geocoding_status: 'success') }
  scope :pending_geocoding, -> { where(geocoding_status: 'pending') }
  scope :failed_geocoding, -> { where(geocoding_status: 'failed') }

  scope :by_postal_code, ->(cp) { where(postal_code: cp) }

  scope :with_coordinates, -> { where.not(latitude: nil).where.not(longitude: nil) }

  def geocoded?
    geocoding_status == 'success'
  end

  def needs_geocoding?
    geocoding_status == 'pending'
  end

  def full_address
    [
      street,
      exterior_number,
      interior_number,
      neighborhood,
      city,
      state,
      country,
      postal_code
    ].compact.join(', ')
  end

  def coordinates
    [latitude, longitude]
  end
end
