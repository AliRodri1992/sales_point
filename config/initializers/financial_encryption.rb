# frozen_string_literal: true

# Production and development must use securely stored, stable Active Record Encryption keys.
# Keys must never be committed to the repository.
%w[PRIMARY_KEY DETERMINISTIC_KEY KEY_DERIVATION_SALT].each do |name|
  key = ENV["ACTIVE_RECORD_ENCRYPTION_#{name}"]
  next if key.blank?

  setting = name.downcase
  Rails.application.config.active_record.encryption.public_send("#{setting}=", key)
end

# Deliberately non-production keys, used only for isolated automated tests.
if Rails.env.test?
  config = Rails.application.config.active_record.encryption
  config.primary_key ||= 'test-only-financial-primary-key-2026-10'
  config.deterministic_key ||= 'test-only-financial-deterministic-key'
  config.key_derivation_salt ||= 'test-only-financial-derivation-salt'
end
