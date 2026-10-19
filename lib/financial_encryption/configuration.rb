# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'tempfile'

module FinancialEncryption
  KEY_NAMES = %w[primary_key deterministic_key key_derivation_salt].freeze

  class IncompleteConfiguration < StandardError; end

  # Prefer explicitly configured, stable secrets over local development keys.
  class Configuration
    def self.resolve(environ:, credentials:, environment:, local_path:)
      supplied = env_keys(environ)
      stored = supplied.size == KEY_NAMES.size ? {} : credential_keys(credentials)
      configured = stored.merge(supplied)
      return require_complete!(configured) if configured.any?
      return LocalKeyStore.fetch_or_create!(local_path) if environment.to_s == 'development'

      {}
    end

    def self.env_keys(environ)
      KEY_NAMES.each_with_object({}) do |name, keys|
        value = environ["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}"]
        keys[name] = value if value.is_a?(String) && !value.empty?
      end
    end

    def self.credential_keys(loader)
      credentials = loader.call
      return {} unless credentials.respond_to?(:[])

      KEY_NAMES.each_with_object({}) do |name, keys|
        value = credentials[name] || credentials[name.to_sym]
        keys[name] = value if value.is_a?(String) && !value.empty?
      end
    rescue ActiveSupport::EncryptedFile::MissingKeyError
      {}
    end

    def self.require_complete!(keys)
      missing = KEY_NAMES - keys.keys
      return keys if missing.empty?

      raise IncompleteConfiguration, "Missing Active Record Encryption keys: #{missing.join(', ')}"
    end

    private_class_method :env_keys, :credential_keys, :require_complete!
  end

  # Stores development-only secrets on the host volume, never in the database
  # or Git. A file lock and atomic rename protect concurrent process startups.
  class LocalKeyStore
    def self.fetch_or_create!(path)
      location = path.to_s
      File.open("#{location}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        create!(location) unless File.exist?(location)
        read!(location)
      end
    end

    def self.create!(path)
      keys = KEY_NAMES.index_with { SecureRandom.hex(32) }
      Tempfile.create(['financial-encryption-', '.tmp'], File.dirname(path)) do |file|
        file.chmod(0o600)
        file.write(JSON.pretty_generate(keys))
        file.flush
        file.fsync
        File.rename(file.path, path)
      end
    end

    def self.read!(path)
      keys = JSON.parse(File.read(path))
      valid = keys.is_a?(Hash) &&
              KEY_NAMES.all? { |name| keys[name].is_a?(String) && keys[name].bytesize >= 32 }
      return keys.slice(*KEY_NAMES) if valid

      raise IncompleteConfiguration, "Invalid encryption keys in #{path}. Restore the original file."
    rescue JSON::ParserError
      raise IncompleteConfiguration, "Invalid encryption key file at #{path}. Restore the original file.", cause: nil
    end

    private_class_method :create!, :read!
  end
end
