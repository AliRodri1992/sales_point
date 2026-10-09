# frozen_string_literal: true

module Admin
  module DemoRequestsHelper
    def demo_request_activity_description(activity)
      values = activity_detail_values(activity.details)
      return activity.details if values.nil? && activity.details.is_a?(String) && activity.details.present?
      return activity_translation(activity.action) if values.nil?

      activity_description_for(activity.action, values)
    end

    private

    def activity_description_for(action, values)
      case action
      when 'status_changed' then status_activity_description(values)
      when 'assigned' then assigned_activity_description(values)
      when 'contact_registered' then contact_activity_description(values)
      when 'follow_up_scheduled' then follow_up_activity_description(values)
      when 'demo_outcome_recorded' then demo_outcome_activity_description(values)
      else activity_translation(action)
      end
    end

    def status_activity_description(values)
      activity_translation(
        'status_changed',
        from: translated_status(values['from']),
        to: translated_status(values['to'])
      )
    end

    def assigned_activity_description(values)
      assignee = values['assigned_to']
      return t('admin.demo_requests.activity.unassigned') if assignee.blank? || assignee == 'unassigned'

      activity_translation('assigned_to', user: assignee)
    end

    def contact_activity_description(values)
      activity_translation(
        'contact_registered',
        channel: translated_value('contact_channels', values['channel']),
        outcome: translated_value('contact_outcomes', values['outcome'])
      )
    end

    def follow_up_activity_description(values)
      activity_translation(
        'follow_up_scheduled',
        date: translated_activity_date(values['date']),
        action: values['action'].presence || '—'
      )
    end

    def demo_outcome_activity_description(values)
      activity_translation(
        'demo_outcome_recorded',
        outcome: translated_value('demo_outcomes', values['outcome'])
      )
    end

    def activity_detail_values(details)
      return details.to_h.stringify_keys if details.respond_to?(:to_h)
      return unless details.is_a?(String) && details.match?(/\\A\\s*\\{.*=>.*\\}\\s*\\z/m)

      details.scan(/:(\\w+)=>(\"(?:\\\\.|[^\"])*\"|[^,}]+)/).to_h do |key, raw_value|
        [key, normalized_activity_value(raw_value)]
      end
    end

    def normalized_activity_value(raw_value)
      value = raw_value.strip
      return value unless value.start_with?('"') && value.end_with?('"')

      value[1...-1].gsub('\\\"', '"').gsub('\\\\', '\\')
    end

    def activity_translation(key, **)
      t("admin.demo_requests.activity.#{key}", **)
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
