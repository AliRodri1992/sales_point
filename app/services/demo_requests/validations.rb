# frozen_string_literal: true

module DemoRequests
  module Validations
    def self.validate_commercial_follow_up(demo_request)
      validate_follow_up_scheduling(demo_request)
      validate_contact_required(demo_request)
      validate_conversion_follow_up(demo_request)
    end

    def self.validate_follow_up_scheduling(demo_request)
      if demo_request.next_action.present? && demo_request.next_follow_up_at.blank?
        demo_request.errors.add(:next_follow_up_at, :blank)
      end
      return unless demo_request.next_follow_up_at.present? && demo_request.next_action.blank?

      demo_request.errors.add(:next_action, :blank)
    end

    def self.validate_contact_required(demo_request)
      return if demo_request.contacted_at.blank?

      demo_request.errors.add(:contact_channel, :blank) if demo_request.contact_channel.blank?
      demo_request.errors.add(:contact_outcome, :blank) if demo_request.contact_outcome.blank?
    end

    def self.validate_conversion_follow_up(demo_request)
      return unless demo_request.converted? && demo_request.converted_at.blank?

      demo_request.errors.add(:converted_at, :blank)
    end
  end
end
