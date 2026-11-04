# frozen_string_literal: true

module SystemRoles
  class StatusReview
    PURPOSE = 'system_role_status_review'

    def initialize(role:, actor:, target:, impact: StatusImpact.new(role))
      @role = role
      @actor = actor
      @target = target
      @impact = impact
    end

    def token
      verifier.generate(payload, expires_in: 20.minutes, purpose: PURPOSE)
    end

    def valid?(token)
      verifier.verified(token.to_s, purpose: PURPOSE) == payload
    end

    private

    def payload
      [@role.id, @actor.id, @target, @impact.fingerprint]
    end

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
