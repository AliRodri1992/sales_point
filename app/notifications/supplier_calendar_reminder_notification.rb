# frozen_string_literal: true

class SupplierCalendarReminderNotification < Noticed::Event
  required_param :event_title
  required_param :scheduled_for

  def message
    t('admin.supplier_calendar.reminder', supplier: record.name,
      title: params[:event_title], date: I18n.l(params[:scheduled_for]))
  end
end
