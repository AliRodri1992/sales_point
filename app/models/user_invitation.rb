# frozen_string_literal: true

require 'digest'

class UserInvitation < ApplicationRecord
  EXPIRATION = 72.hours
  DELIVERY_STATES = %w[pending queued sent failed].freeze
  belongs_to :user
  belongs_to :organization
  attr_accessor :raw_token

  validates :delivery_status, inclusion: { in: DELIVERY_STATES }

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil) }

  def self.issue!(user:, organization:)
    raise ArgumentError, 'User must be pending' unless user.pending?
    raise ArgumentError, 'Membership required' unless user.organization_memberships.active.exists?(organization:)

    user.with_lock do
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
    user.with_lock do
      lock!
      return false unless usable?

      digest = Digest::SHA256.hexdigest(token.to_s)
      return false unless ActiveSupport::SecurityUtils.secure_compare(token_digest, digest)

      return false unless acceptable_password?(password)

      activate_account!(password, password_confirmation)
    end
  end

  private

  def activate_account!(password, confirmation)
    user.password = password
    user.password_confirmation = confirmation
    user.status = :active
    return false unless user.save

    user.organization_memberships.active.find_by!(organization:).update!(account_status: :active)
    update!(accepted_at: Time.current)
    true
  end

  def acceptable_password?(password)
    return true if password.to_s.length >= 9

    user.errors.add(:password, :too_short, count: 9)
    false
  end
end
