# frozen_string_literal: true

module Users
  class StatusIncidentManager
    def initialize(user:, organization:, actor:, description:, resolution:)
      @user = user
      @organization = organization
      @actor = actor
      @description = description
      @resolution = resolution
    end

    def review_date(target, value)
      return unless target == 'suspended' && value.present?

      time = Time.zone.parse(value.to_s)
      raise ArgumentError, 'Review date must be in the future' unless time&.future?

      time
    end

    def open!
      UserSecurityIncident.create!(
        user: @user, organization: @organization,
        opened_by: @actor, description: @description
      )
    end

    def validate_resolution!
      raise ArgumentError, 'Incident resolution required' if @resolution.blank?

      incident = UserSecurityIncident.where(user: @user, organization: @organization, resolved_at: nil)
                                     .order(created_at: :desc).first
      raise ArgumentError, 'Security incident not found' unless incident

      incident.update!(resolution: @resolution, resolved_at: Time.current, resolved_by: @actor)
    end
  end
end
