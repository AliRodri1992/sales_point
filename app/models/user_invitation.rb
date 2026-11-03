# frozen_string_literal: true

require 'digest'

class UserInvitation < ApplicationRecord
  EXPIRATION = 72.hours
  belongs_to :user
  belongs_to :organization
  attr_accessor :raw_token

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil) }

  def self.issue!(user:, organization:)
    raise ArgumentError, 'User must be pending' unless user.pending?
    raise ArgumentError, 'Membership required' unless user.organization_memberships.active.exists?(organization:)

    transaction do
      user.user_invitations.pending.find_each { |old| old.update!(revoked_at: Time.current) }
      token = SecureRandom.urlsafe_base64(48)
      create!(user:, organization:, token_digest: Digest::SHA256.hexdigest(token),
              expires_at: EXPIRATION.from_now).tap { |record| record.raw_token = token }
    end
  end

  def self.revoke_for!(user)
    user.user_invitations.pending.find_each { |invitation| invitation.update!(revoked_at: Time.current) }
  end

  def usable?
    accepted_at.nil? && revoked_at.nil? && expires_at.future? &&
      user.pending? && user.deleted_at.nil? &&
      user.organization_memberships.active.exists?(organization:)
  end

  def accept!(token:, password:, password_confirmation:)
    transaction do
      lock!
      return false unless usable?

      digest = Digest::SHA256.hexdigest(token.to_s)
      return false unless ActiveSupport::SecurityUtils.secure_compare(token_digest, digest)

      user.password = password
      user.password_confirmation = password_confirmation
      user.status = :active
      return false unless user.save

      update!(accepted_at: Time.current)
      true
    end
  end
end
