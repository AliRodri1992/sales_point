# frozen_string_literal: true

module Admin
  module SupplierDossierHelper
    # Weekly supplier arrangements are not confirmed appointments.
    # Show the next occurrence calculated from the weekday and start time.
    def supplier_dossier_next_occurrence(schedule, now: Time.zone.now)
      timezone = schedule.supplier&.organization&.organization_settings&.active_records&.pick(:timezone)
      zone = ActiveSupport::TimeZone[timezone] || Time.zone
      local_now = now.in_time_zone(zone)
      date = local_now.to_date
      date += (schedule.weekday - date.wday) % 7
      date += 7.days if date == local_now.to_date && schedule.starts_at.strftime('%H:%M') < local_now.strftime('%H:%M')
      53.times do
        return date if schedule.occurs_on?(date)

        date += 7.days
      end
      date
    end
  end
end
