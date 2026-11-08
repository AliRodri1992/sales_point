# frozen_string_literal: true

module EmailTemplates
  class TestRecipient
    include ActiveModel::Model

    attr_reader :email
    attr_accessor :actor

    validates :email, presence: true, length: { maximum: 254 }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validate :recipient_must_match_actor

    def email=(value)
      @email = value.to_s.strip.downcase
    end

    private

    def recipient_must_match_actor
      return if errors[:email].any? || actor&.role?('super_admin')
      return if actor && email == actor.email.to_s.strip.downcase

      errors.add(:email, :invalid)
    end
  end
end
