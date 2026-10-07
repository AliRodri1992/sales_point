# frozen_string_literal: true

module DemoRequests
  class Workflow
    def initialize(demo_request, current_user, previous_status, previous_assignee)
      @demo_request = demo_request
      @current_user = current_user
      @previous_status = previous_status
      @previous_assignee = previous_assignee
    end

    def call
      record_workflow_activity
      record_commercial_activity
      Reminders.new(@demo_request, @current_user).reset_if_rescheduled
      Reminders.new(@demo_request, @current_user).schedule(@previous_status)
      Reminders.new(@demo_request, @current_user).send_confirmation(@previous_status)
      notify_assignee
    end

    private

    def record_workflow_activity
      return if @previous_status == @demo_request.status && @previous_assignee == @demo_request.assigned_to_id

      action = @previous_assignee == @demo_request.assigned_to_id ? 'status_changed' : 'assigned'
      @demo_request.activities.create!(
        user: @current_user,
        action:,
        details: build_details(action)
      )
    end

    def build_details(action)
      case action
      when 'status_changed'
        { from: @previous_status, to: @demo_request.status }
      else
        { assigned_to: @demo_request.assigned_to&.display_name || 'unassigned' }
      end
    end

    def record_commercial_activity
      CommercialActivities.new(@demo_request, @current_user).record_all
    end

    def notify_assignee
      return if @demo_request.assigned_to.blank?

      action = @previous_assignee == @demo_request.assigned_to_id ? 'status_changed' : 'assigned'
      DemoRequestMailer.with(
        demo_request: @demo_request,
        assignee: @demo_request.assigned_to,
        actor: @current_user,
        action:,
        locale: @demo_request.assigned_to.language&.code || I18n.locale.to_s
      ).workflow_update.deliver_later
    end
  end
end
