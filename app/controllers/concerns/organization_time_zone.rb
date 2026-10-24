# frozen_string_literal: true

# Keep organization-local calendar input and output in a single request time zone.
# Rails resets Time.zone at the end of the block, including on exceptions.
module OrganizationTimeZone
  extend ActiveSupport::Concern

  included do
    around_action :with_organization_time_zone
  end

  private

  def with_organization_time_zone(&)
    organization = current_organization
    settings = organization.organization_settings.active_records.first if organization
    zone = settings&.timezone
    Time.use_zone(ActiveSupport::TimeZone[zone] || Time.zone, &)
  end
end
