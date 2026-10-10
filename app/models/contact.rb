# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :contactable, polymorphic: true

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :available, -> { not_deleted.where(active: true) }

  validates :name, presence: true, length: { maximum: 150 }
  validates :position, length: { maximum: 100 }, allow_blank: true
  validates :email, length: { maximum: 150 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, :mobile_phone, length: { maximum: 30 }, allow_blank: true
  validate :single_active_primary

  before_validation :normalize_fields

  private

  def normalize_fields
    self.name = strip_and_preserve(name)
    self.position = strip_and_preserve(position)
    self.email = strip_and_preserve(email)&.downcase
    self.phone = strip_and_preserve(phone)
    self.mobile_phone = strip_and_preserve(mobile_phone)
    self.notes = strip_and_preserve(notes)
  end

  def strip_and_preserve(value)
    value.to_s.strip.presence
  end

  def single_active_primary
    return unless primary? && active? && deleted_at.nil? && contactable.present?
    return unless contactable.persisted?

    duplicates = available_contacts_for_contactable
    duplicates.where.not(id: id) if persisted?
    errors.add(:primary, :taken) if duplicates.exists?
  end

  def available_contacts_for_contactable
    Contact.available.where(
      contactable_type: contactable.class.base_class.name,
      contactable_id: contactable.id,
      primary: true
    )
  end
end
