# frozen_string_literal: true

module Users
  class OrganizationCapacity
    FEATURE_KEY = 'users_limit'

    class CapacityExceeded < StandardError; end

    def initialize(organization:)
      @organization = organization
    end

    def limit
      plan = @organization.membership_plan
      return unless plan&.active?

      feature = plan.membership_plan_features
                    .joins(:membership_feature)
                    .find_by(membership_features: { key: FEATURE_KEY },
                             enabled: true, deleted_at: nil)
      feature&.limit
    end

    def occupied
      @organization.organization_memberships
                   .where(deleted_at: nil, status: 'active',
                          account_status: %w[pending active suspended blocked]).count
    end

    def ensure_available!(additional: 1)
      maximum = limit
      return if maximum.nil? || occupied + additional <= maximum

      raise CapacityExceeded, "Organization user limit of #{maximum} reached"
    end
  end
end
