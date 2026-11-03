# frozen_string_literal: true

class EmailSenderSetting < ApplicationRecord
  belongs_to :organization, optional: true

  validates :default_locale, inclusion: { in: %w[es en ko] }
  validates :domain_status, inclusion: { in: %w[unverified pending verified rejected] }
  validates :from_address, :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
