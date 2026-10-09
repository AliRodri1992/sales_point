# frozen_string_literal: true

module Admin
  module DemoRequestsHelper
    def demo_request_activity_description(activity)
      details = activity.details
      values = activity_detail_values(details)
      return details if values.nil? && details.is_a?(String) && details.present?
      return activity_translation(activity.action) if values.nil?

      case activity.action
      when 'status_changed'
        activity_translation(
          activity.action,
          from: translated_status(values['from']),
          to: translated_status(values['to'])
        )
      when 'assigned'
        assignee = values['assigned_to']
        return t('admin.demo_requests.activity.unassigned') if assignee.blank? || assignee == 'unassigned'

        activity_translation('assigned_to', user: assignee)
      when 'contact_registered'
        activity_translation(
          activity.action,
          channel: translated_value('contact_channels', values['channel']),
          outcome: translated_value('contact_outcomes', values['outcome'])
        )
      when 'follow_up_scheduled'
        activity_translation(
          activity.action,
          date: translated_activity_date(values['date']),
          action: values['action'].presence || '—'
        )
      when 'demo_outcome_recorded'
        activity_translation(
          activity.action,
          outcome: translated_value('demo_outcomes', values['outcome'])
        )
      else
        activity_translation(activity.action)
      end
    end

    private

    def activity_detail_values(details)
      return details.to_h.stringify_keys if details.respond_to?(:to_h)
      return unless details.is_a?(String) && details.match?(/\A\s*\{.*=>.*\}\s*\z/m)

      details.scan(/:(\w+)=>("(?:\\.|[^"])*"|[^,}]+)/).to_h do |key, raw_value|
        value = raw_value.strip
        value = if value.start_with?('"') && value.end_with?('"')
                  value[1...-1].gsub('\\\"', '"').gsub('\\\\', '\\')
                else
                  value
                end
        [key, value]
      end
    end

    def activity_translation(key, **options)
      t("admin.demo_requests.activity.#{key}", **options)
    end

    def translated_status(status)
      return '—' if status.blank?

      t("admin.demo_requests.statuses.#{status}", default: status.humanize)
    end

    def translated_value(group, value)
      return '—' if value.blank?

      t("admin.demo_requests.#{group}.#{value}", default: value.humanize)
    end

    def translated_activity_date(value)
      return '—' if value.blank?

      date = value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      l(date, format: :short)
    rescue ArgumentError, TypeError
      value.to_s
    end
  end
end
