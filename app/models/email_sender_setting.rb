# frozen_string_literal: true

class EmailSenderSetting < ApplicationRecord
  belongs_to :organization, optional: true

  before_validation :normalize_addresses

  validates :display_name, presence: true, length: { maximum: 150 }
  validates :from_address, presence: true
  validates :from_address, :reply_to, length: { maximum: 254 }
  validates :default_locale, inclusion: { in: %w[es en ko] }
  validates :domain_status, inclusion: { in: %w[unverified pending verified rejected] }
  validates :from_address, :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :domain, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/i }, allow_blank: true

  private

  def normalize_addresses
    self.from_address = from_address.to_s.strip.downcase.presence
    self.reply_to = reply_to.to_s.strip.downcase.presence
  end
end
