# frozen_string_literal: true

class Phone < ApplicationRecord
  KINDS = %w[mobile landline other].freeze
  PHONEABLE_TYPES = %w[Contact Client Branch Employee].freeze

  belongs_to :organization
  belongs_to :phoneable, polymorphic: true

  scope :active, -> { where(deleted_at: nil) }

  validates :kind, inclusion: { in: KINDS }
  validates :phoneable_type, inclusion: { in: PHONEABLE_TYPES }
  validates :country_code, presence: true, format: { with: /\A[A-Z]{2}\z/ }
  validates :label, length: { maximum: 60 }, allow_blank: true
  validates :extension, length: { maximum: 10 }, allow_blank: true
  validates :number, presence: true
  validate :number_must_be_valid
  validate :same_organization_as_owner
  validate :unique_primary_per_kind
  validate :unique_active_number

  before_validation :assign_organization
  before_validation :normalize_number
  before_validation :normalize_metadata

  private

  def phone_owner
    phoneable.is_a?(Contact) ? phoneable.contactable : phoneable
  end

  def owner_organization
    owner = phone_owner
    return owner if owner.is_a?(Organization)

    owner.organization if owner.respond_to?(:organization)
  end

  def assign_organization
    self.organization ||= owner_organization
  end

  def normalize_number
    return if number.blank?

    parsed = Phonelib.parse(number.to_s.strip, country_code.presence || 'MX')
    self.number = parsed.e164 if parsed.valid?
  end

  def normalize_metadata
    self.country_code = country_code.to_s.upcase.presence || 'MX'
    self.label = label.to_s.strip.presence
    self.extension = extension.to_s.strip.presence
  end

  def number_must_be_valid
    return if number.blank?

    errors.add(:number, :invalid) unless Phonelib.parse(number, country_code).valid?
  end

  def same_organization_as_owner
    return if organization.blank? || owner_organization.blank?

    errors.add(:organization, :invalid) if organization_id != owner_organization.id
  end

  def unique_primary_per_kind
    return unless primary? && deleted_at.nil? && phoneable&.persisted?

    errors.add(:primary, :taken) if conflicting_primary_phone?
  end

  def unique_active_number
    return if deleted_at.present? || phoneable.blank? || number.blank? || !phoneable.persisted?

    duplicates = Phone.active.where(phoneable:, number:, extension:).where.not(id: id)
    errors.add(:number, :taken) if duplicates.exists?
  end

  def conflicting_primary_phone?
    Phone.active.where(phoneable:, kind:, primary: true).where.not(id: id).exists?
  end
end
