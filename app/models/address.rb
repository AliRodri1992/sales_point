# frozen_string_literal: true

class Address < ApplicationRecord
  has_paper_trail if: ->(record) { record.addressable_type == 'Supplier' }

  belongs_to :addressable, polymorphic: true
  belongs_to :country

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :primary_addresses, -> { not_deleted.where(primary: true) }

  PURPOSES = %w[general fiscal commercial delivery].freeze

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
  validates :exterior_number, length: { maximum: 20 }, on: %i[create update]
  validates :interior_number, length: { maximum: 20 }, allow_blank: true, on: %i[create update]
  validates :reference_notes, length: { maximum: 200 }, allow_blank: true, on: %i[create update]
  validates :neighborhood, length: { maximum: 100 }, allow_blank: true, on: %i[create update]
  validates :city, presence: true, length: { in: 2..100 }, on: %i[create update]
  validates :state, length: { maximum: 100 }, allow_blank: true, on: %i[create update]
  validate :validate_country_address, on: %i[create update onboardingstep2]
  before_validation :invalidate_stale_coordinates, on: %i[create update]

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

  def geocoded?
    geocoding_status == 'success'
  end

  def needs_geocoding?
    geocoding_status == 'pending'
  end

  def full_address
    [street, exterior_number, interior_number, neighborhood, city, state, country&.name, postal_code].compact.join(', ')
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

  def validate_country_address
    rule = Addresses::CountryRules.new(country&.iso_alpha2)
    errors.add(:exterior_number, :blank) if rule.exterior_required? && exterior_number.blank?
    errors.add(:neighborhood, :blank) if rule.neighborhood_required? && neighborhood.blank?
    errors.add(:state, :blank) if rule.state_required? && state.blank?
    errors.add(:postal_code, :blank) if rule.postal_required? && postal_code.blank?
    return if postal_code.blank?

    errors.add(:postal_code, :invalid) unless rule.valid_postal_code?(postal_code)
  end

  def invalidate_stale_coordinates
    fields = %w[street exterior_number interior_number neighborhood city state postal_code country_id]
    return unless persisted? && fields.any? { |name| will_save_change_to_attribute?(name) }
    return if will_save_change_to_location_confirmed_at? && location_confirmed_at.present?

    self.latitude = nil
    self.longitude = nil
    self.location_confirmed_at = nil
    self.geocoding_status = 'pending'
  end

  def coordinates
    [latitude, longitude]
  end
end
