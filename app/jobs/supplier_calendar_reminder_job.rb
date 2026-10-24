# frozen_string_literal: true

class SupplierCalendarReminderJob < ApplicationJob
  queue_as :default

  def perform(today = nil)
    Organization.active_records.find_each do |organization|
      zone = organization.organization_settings.active_records.first&.timezone
      timezone = ActiveSupport::TimeZone[zone] if zone.present?
      Time.use_zone(timezone || Time.zone) do
        date = (today || Date.current) + 1
        remind_events(organization, date)
        remind_schedules(organization, date)
      end
    end
  end

  private

  def remind_events(organization, date)
    range = date.in_time_zone.beginning_of_day...(date + 1).in_time_zone.beginning_of_day
    SupplierEvent.not_deleted.where(supplier_id: organization.suppliers.available.select(:id))
                 .where(starts_at: range, status: 'scheduled').includes(supplier: :responsible_user)
                 .find_each { |event| notify(event.supplier, event, date, event.title) }
  end

  def remind_schedules(organization, date)
    SupplierSchedule.not_deleted.where(supplier_id: organization.suppliers.available.select(:id), weekday: date.wday)
                    .includes(supplier: :responsible_user).find_each do |schedule|
      notify(schedule.supplier, schedule, date, schedule.kind) if schedule.occurs_on?(date)
    end
  end

  def notify(supplier, activity, date, title)
    recipient = supplier.responsible_user
    return unless authorized_recipient?(recipient, supplier)

    key = Digest::SHA256.hexdigest([activity.class.name, activity.id, date.iso8601, recipient.id].join(':'))
    return unless new_delivery?(supplier, recipient, key)

    SupplierCalendarReminderNotification.with(record: supplier, event_title: title, scheduled_for: date)
                                        .deliver(recipient, enqueue_job: false)
    recipient.broadcast_notifications_refresh
  end

  def authorized_recipient?(recipient, supplier)
    recipient && recipient.organization_memberships.active.exists?(organization_id: supplier.organization_id)
  end

  def new_delivery?(supplier, recipient, key)
    SupplierEventDelivery.create_or_find_by!(event_key: key) do |record|
      record.supplier = supplier
      record.recipient = recipient
    end.previously_new_record?
  end
end
