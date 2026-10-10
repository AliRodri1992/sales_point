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
    self.name = name.to_s.strip
    self.position = position.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence
    self.phone = phone.to_s.strip.presence
    self.mobile_phone = mobile_phone.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end

  def single_active_primary
    return unless primary? && active? && deleted_at.nil? && contactable.present?

    duplicates = Contact.available.where(contactable_type: contactable.class.base_class.name,
                                         contactable_id: contactable.id, primary: true)
    duplicates = duplicates.where.not(id: id) if persisted?
    errors.add(:primary, :taken) if contactable.persisted? && duplicates.exists?
  end
end
