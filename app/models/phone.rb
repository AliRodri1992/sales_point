# frozen_string_literal: true

class Phone < ApplicationRecord
  KINDS = %w[mobile landline other].freeze

  belongs_to :organization
  belongs_to :phoneable, polymorphic: true

  scope :active, -> { where(deleted_at: nil) }

  validates :kind, inclusion: { in: KINDS }
  validates :country_code, presence: true, format: { with: /\A[A-Z]{2}\z/ }
  validates :label, length: { maximum: 60 }, allow_blank: true
  validates :extension, length: { maximum: 10 }, allow_blank: true
  validates :number, presence: true
  validate :number_must_be_valid
  validate :same_organization_as_owner
  validate :unique_primary_per_kind

  before_validation :assign_organization
  before_validation :normalize_number
  before_validation :normalize_metadata

  private

  def assign_organization
    owner = phoneable.is_a?(Contact) ? phoneable.contactable : phoneable
    self.organization ||= owner.is_a?(Organization) ? owner : owner.organization if owner&.respond_to?(:organization) || owner.is_a?(Organization)
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
    return if phoneable.blank? || organization.blank?
    owner = phoneable.is_a?(Contact) ? phoneable.contactable : phoneable
    owner_id = owner.is_a?(Organization) ? owner.id : owner.organization_id if owner.respond_to?(:organization_id) || owner.is_a?(Organization)
    errors.add(:organization, :invalid) if owner_id.present? && owner_id != organization_id
  end

  def unique_primary_per_kind
    return unless primary? && deleted_at.nil? && phoneable&.persisted?

    others = Phone.active.where(phoneable_type: phoneable.class.base_class.name,
                                phoneable_id: phoneable.id, kind:, primary: true)
    errors.add(:primary, :taken) if others.where.not(id: id).exists?
  end
end
