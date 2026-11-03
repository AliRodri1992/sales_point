# frozen_string_literal: true

module Users
  class InvitationDeliveryToken
    def self.encrypt(token)
      encryptor.encrypt_and_sign(token)
    end

    def self.decrypt(ciphertext)
      encryptor.decrypt_and_verify(ciphertext)
    end

    def self.encryptor
      secret = Rails.application.key_generator.generate_key('delta-pos-invitation-delivery', 32)
      ActiveSupport::MessageEncryptor.new(secret)
    end
  end
end
