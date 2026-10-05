# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  enum :geocoding_status, {
    pending: 'pending',
    success: 'success',
    failed: 'failed'
  }

  validates :street, presence: true, length: { in: 2..150 }, on: %i[create update]
  validates :exterior_number, presence: true, length: { in: 1..20 }, on: %i[create update]
  validates :interior_number, length: { maximum: 20 }, allow_blank: true, on: %i[create update]
  validates :neighborhood, presence: true, length: { in: 2..100 }, on: %i[create update]
  validates :city, presence: true, length: { in: 2..100 }, on: %i[create update]
  validates :state, presence: true, length: { in: 2..100 }, on: %i[create update]
  validates :country, presence: true, length: { in: 2..100 }, on: %i[create update]
  validates :postal_code,
            presence: true,
            format: { with: /\A[0-9]{5}\z/ },
            on: %i[create update]
  validates :latitude,
            numericality: {
              greater_than_or_equal_to: -90,
              less_than_or_equal_to: 90
            },
            allow_nil: true,
            on: %i[create update]
  validates :longitude,
            numericality: {
              greater_than_or_equal_to: -180,
              less_than_or_equal_to: 180
            },
            allow_nil: true,
            on: %i[create update]
  validates :geocoding_status,
            presence: true,
            inclusion: { in: geocoding_statuses.keys },
            on: %i[create update]

  validates :street, presence: true, length: { in: 2..150 }, on: :onboardingstep2
  validates :exterior_number, presence: true, length: { in: 1..20 }, on: :onboardingstep2
  validates :interior_number, length: { maximum: 20 }, allow_blank: true, on: :onboardingstep2
  validates :neighborhood, presence: true, length: { in: 2..100 }, on: :onboardingstep2
  validates :city, presence: true, length: { in: 2..100 }, on: :onboardingstep2
  validates :state, presence: true, length: { in: 2..100 }, on: :onboardingstep2
  validates :country, presence: true, length: { in: 2..100 }, on: :onboardingstep2
  validates :postal_code,
            presence: true,
            format: { with: /\A[0-9]{5}\z/ },
            on: :onboardingstep2

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
    [street, exterior_number, interior_number, neighborhood, city, state, country, postal_code].compact.join(', ')
  end

  def coordinates
    [latitude, longitude]
  end
end
