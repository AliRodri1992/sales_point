# frozen_string_literal: true

# Keep organization-local calendar input and output in a single request time zone.
# Rails resets Time.zone at the end of the block, including on exceptions.
module OrganizationTimeZone
  extend ActiveSupport::Concern

  included do
    around_action :with_organization_time_zone
  end

  private

  def with_organization_time_zone(&action)
    zone = current_organization&.organization_setting&.timezone
    Time.use_zone(ActiveSupport::TimeZone[zone] || Time.zone, &action)
  end
end
