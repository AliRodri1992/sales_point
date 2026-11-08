# frozen_string_literal: true

class EmailSenderSetting < ApplicationRecord
  belongs_to :organization, optional: true

  before_validation :normalize_addresses
  before_validation :normalize_display_name
  before_validation :sync_domain_from_sender

  validates :display_name, presence: true, length: { maximum: 150 }
  validates :from_address, presence: true
  validates :from_address, :reply_to, length: { maximum: 254 }
  validates :default_locale, inclusion: { in: %w[es en ko] }
  validates :domain_status, inclusion: { in: %w[unverified pending verified rejected] }
  validates :from_address, :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :domain, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/i }, allow_blank: true

  private

  # A verified domain cannot remain trusted after the sender switches domains.
  def sync_domain_from_sender
    candidate = from_address.to_s.split('@', 2).last
    return unless candidate.to_s.match?(/\A[a-z0-9.-]+\.[a-z]{2,}\z/i)

    if domain.blank?
      self.domain = candidate
    elsif persisted? && will_save_change_to_from_address? && !domain.casecmp?(candidate)
      self.domain = candidate
      self.domain_status = 'unverified'
    end
  end

  def normalize_display_name
    self.display_name = display_name.strip if display_name.is_a?(String)
  end

  def normalize_addresses
    self.from_address = from_address.to_s.strip.downcase.presence
    self.reply_to = reply_to.to_s.strip.downcase.presence
  end
end
