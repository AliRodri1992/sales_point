# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :contactable, polymorphic: true

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { not_deleted.where(active: true) }

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

  validates :name, presence: true, length: { maximum: 150 }
  validates :position, length: { maximum: 100 }, allow_blank: true
  validates :email, length: { maximum: 150 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, :mobile_phone, length: { maximum: 30 }, allow_blank: true
  validate :single_active_primary

  before_validation :normalize_fields

  private

  def normalize_fields
    self.name = normalize_string(name)
    self.position = normalize_optional(position)
    self.email = normalize_string(email, downcase: true)
    self.phone = normalize_optional(phone)
    self.mobile_phone = normalize_optional(mobile_phone)
    self.notes = normalize_optional(notes)
  end

  def normalize_string(value, downcase: false)
    result = value.to_s.strip
    result = result.downcase if downcase
    result.presence
  end

  def normalize_optional(value)
    value.to_s.strip.presence
  end

  def single_active_primary
    return unless primary? && active? && deleted_at.nil? && contactable.present?
    return unless contactable.persisted?

    has_primary = available_contacts
                  .where.not(id: id)
                  .exists?
    errors.add(:primary, :taken) if has_primary
  end

  def available_contacts
    Contact.available.where(
      contactable_type: contactable.class.base_class.name,
      contactable_id: contactable.id,
      primary: true
    )
  end
end
