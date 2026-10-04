# frozen_string_literal: true

module Onboarding
  class Auditor
    def self.call(organization:, user:, action:, step: nil, section: nil, metadata: {})
      OnboardingAudit.create!(
        organization:,
        user:,
        action:,
        step:,
        section:,
        metadata:
      )
    end
  end
end
