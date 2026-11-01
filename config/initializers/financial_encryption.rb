# frozen_string_literal: true

require Rails.root.join('lib/financial_encryption/configuration')

# Explicit environment variables take priority over Rails credentials.
# In development only, a missing configuration is created once in a local,
# gitignored file shared by Docker web and Sidekiq containers.
encryption_keys = FinancialEncryption::Configuration.resolve(
  environ: ENV,
  credentials: -> { Rails.application.credentials[:active_record_encryption] },
  environment: Rails.env,
  local_path: Rails.root.join('config/financial_encryption.local.json')
)

config = Rails.application.config.active_record.encryption
encryption_keys.each { |name, value| config.public_send("#{name}=", value) }

# Deliberately non-production keys, used only for isolated automated tests.
if Rails.env.test?
  config.primary_key ||= 'test-only-financial-primary-key-2026-10'
  config.deterministic_key ||= 'test-only-financial-deterministic-key'
  config.key_derivation_salt ||= 'test-only-financial-derivation-salt'
end
