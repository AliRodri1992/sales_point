# frozen_string_literal: true

class Address < ApplicationRecord
  include AddressLocation

  has_paper_trail if: ->(record) { record.addressable_type == 'Supplier' }

  belongs_to :addressable, polymorphic: true
  belongs_to :country

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :primary_addresses, -> { not_deleted.where(primary: true) }

  PURPOSES = %w[general fiscal commercial delivery].freeze
  GEOGRAPHIC_FIELDS = %w[street exterior_number interior_number neighborhood city state postal_code country_id].freeze

  validates :purpose, inclusion: { in: PURPOSES }
  validate :single_primary_address

  def restore_safely
    return false if deleted_at.nil?

    original_deleted_at = deleted_at
    self.deleted_at = nil
    return true if save

    self.deleted_at = original_deleted_at
    false
  rescue ActiveRecord::RecordNotUnique
    self.deleted_at = original_deleted_at
    errors.add(:primary, :taken)
    false
  end

  enum :geocoding_status, {
    pending: 'pending',
    success: 'success',
    failed: 'failed'
  }

  validates :street, presence: true, length: { in: 2..150 }, on: %i[create update]
  validates :exterior_number, length: { in: 1..20 }, allow_blank: true, on: %i[create update]
  validates :interior_number, length: { maximum: 20 }, allow_blank: true, on: %i[create update]
  validates :reference_notes, length: { maximum: 200 }, allow_blank: true, on: %i[create update]
  validates :location_adjustment_reason, length: { maximum: 250 }, allow_blank: true
  validates :geocoding_confidence, numericality: { in: 0..1 }, allow_nil: true
  validates :neighborhood, length: { in: 2..100 }, allow_blank: true, on: %i[create update]
  validates :city, presence: true, length: { in: 2..100 }, on: %i[create update]
  validates :state, length: { in: 2..100 }, allow_blank: true, on: %i[create update]
  before_validation :clear_unused_supplier_fields
  validate :check_country_requirements, on: %i[create update onboardingstep2]

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
  validates :city, presence: true, length: { in: 2..100 }, on: :onboardingstep2

  scope :active, -> { not_deleted }

  scope :geocoded, -> { where(geocoding_status: 'success') }
  scope :pending_geocoding, -> { where(geocoding_status: 'pending') }
  scope :failed_geocoding, -> { where(geocoding_status: 'failed') }

  scope :by_postal_code, ->(cp) { where(postal_code: cp) }

  scope :with_coordinates, -> { where.not(latitude: nil).where.not(longitude: nil) }

  def single_primary_address
    return unless primary? && deleted_at.nil? && addressable&.persisted?

    errors.add(:primary, :taken) if other_primary_address_exists?
  end

  def other_primary_address_exists?
    Address.with_deleted.where(
      addressable_type: addressable.class.base_class.name,
      addressable_id: addressable.id, purpose: purpose, primary: true, deleted_at: nil
    ).where.not(id: id).exists?
  end

  def low_geocoding_confidence?
    geocoding_confidence.present? && geocoding_confidence < 0.8
  end

  def geocoded?
    geocoding_status == 'success'
  end

  def needs_geocoding?
    geocoding_status == 'pending'
  end

  def full_address
    [street, exterior_number, interior_number, neighborhood, city, state, country&.name, postal_code].compact.join(', ')
  end

  def coordinates
    [latitude, longitude]
  end

  private

  def clear_unused_supplier_fields
    return unless addressable_type == 'Supplier' && country

    rules = Addresses::CountryRules.new(country.iso_alpha2)
    self.postal_code = nil unless rules.postal_required?
    self.neighborhood = nil unless rules.neighborhood_applicable?
  end

  def check_country_requirements
    Addresses::CountryRules.new(country&.iso_alpha2).validate(self)
  end
end
