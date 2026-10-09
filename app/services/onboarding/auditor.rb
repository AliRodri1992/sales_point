# frozen_string_literal: true

module Onboarding
  class Auditor
    def self.call(organization:, user:, action:, **attributes)
      OnboardingAudit.create!(
        organization:,
        user:,
        action:,
        **attributes
      )
    end
  end
end
