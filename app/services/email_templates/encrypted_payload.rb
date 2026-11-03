# frozen_string_literal: true

module EmailTemplates
  class EncryptedPayload
    def self.encrypt(attributes)
      encryptor.encrypt_and_sign(attributes.to_json)
    end

    def self.decrypt(ciphertext)
      JSON.parse(encryptor.decrypt_and_verify(ciphertext)).deep_symbolize_keys
    end

    def self.encryptor
      secret = Rails.application.key_generator.generate_key('delta-pos-email-dispatch-v1', 32)
      ActiveSupport::MessageEncryptor.new(secret)
    end
  end
end
