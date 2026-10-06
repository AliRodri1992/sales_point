# frozen_string_literal: true

module Admin
  class DemoRequestsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_demo_request, only: %i[show update]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    def index
      authorize DemoRequest
      load_demo_requests
      @total_count = @demo_requests.except(:limit, :offset).count
      @users = active_users
      @metrics = commercial_metrics
    end

    def show
      authorize @demo_request
      @users = active_users
      @activities = @demo_request.activities.includes(:user).order(created_at: :desc)
    end

    def update
      authorize @demo_request

      previous_status = @demo_request.status
      previous_assignee = @demo_request.assigned_to_id

      if @demo_request.update(demo_request_params)
        record_workflow_activity(previous_status, previous_assignee)
        record_commercial_activity
        record_note
        reset_demo_reminders_if_rescheduled
        schedule_demo_reminders(previous_status)
        send_scheduled_confirmation(previous_status)
        notify_assignee_of_workflow_change(previous_status, previous_assignee)
        redirect_to admin_demo_request_path(@demo_request),
                    flash: { swal_message: t('admin.demo_requests.updated') }
      else
        @users = active_users
        @activities = @demo_request.activities.includes(:user).order(created_at: :desc)
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_demo_request
      @demo_request = DemoRequest.find(params[:id])
    end

    def load_demo_requests
      scope = policy_scope(DemoRequest).includes(:assigned_to)
      scope = scope.where(status: params[:status]) if DemoRequest.statuses.key?(params[:status])

      if params[:follow_up].present?
        scope = scope.where.not(next_follow_up_at: nil)
                      .where.not(status: %w[converted cancelled])
        scope = scope.where('next_follow_up_at <= ?', Time.current) if params[:follow_up] == 'overdue'
        scope = scope.where('next_follow_up_at > ?', Time.current) if params[:follow_up] == 'upcoming'
      end

      if params[:contact_outcome].present? && DemoRequest::CONTACT_OUTCOMES.include?(params[:contact_outcome])
        scope = scope.where(contact_outcome: params[:contact_outcome])
      end

      if params[:demo_outcome].present? && DemoRequest::DEMO_OUTCOMES.include?(params[:demo_outcome])
        scope = scope.where(demo_outcome: params[:demo_outcome])
      end

      if params[:search].present?
        term = "%#{DemoRequest.sanitize_sql_like(params[:search].strip)}%"
        scope = scope.where(
          'name ILIKE :term OR email ILIKE :term OR company ILIKE :term OR phone ILIKE :term',
          term:
        )
      end

      @total_count = scope.count
      @per_page = per_page_param
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      @demo_requests = scope.order(Arel.sql('CASE WHEN next_follow_up_at IS NOT NULL AND next_follow_up_at <= NOW() THEN 0 ELSE 1 END, created_at DESC'))
                            .limit(@per_page)
                            .offset((@current_page - 1) * @per_page)
    end

    def commercial_metrics
      scope = policy_scope(DemoRequest)
      counts = scope.group(:status).count
      {
        total: scope.count,
        pending: counts.fetch('pending', 0),
        contacted: counts.fetch('contacted', 0),
        scheduled: counts.fetch('scheduled', 0),
        completed: counts.fetch('completed', 0),
        converted: counts.fetch('converted', 0),
        overdue_follow_ups: scope.where.not(next_follow_up_at: nil)
                                .where('next_follow_up_at <= ?', Time.current)
                                .where.not(status: %w[converted cancelled]).count,
        conversion_rate: scope.count.zero? ? 0 : ((counts.fetch('converted', 0).to_f / scope.count) * 100).round(1)
      }
    end

    def active_users
      User.active.where(user_type: :employee).order(Arel.sql("COALESCE(username, email) ASC"))
    end

    def per_page_param
      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def demo_request_params
      params.expect(
        demo_request: %i[
          status
          assigned_to_id
          scheduled_at
          note
          contacted_at
          contact_channel
          contact_outcome
          next_follow_up_at
          next_action
          demo_outcome
        ]
      )
    end

    def record_commercial_activity
      if @demo_request.saved_change_to_contacted_at?
        @demo_request.activities.create!(
          user: current_user,
          action: 'contact_registered',
          details: t(
            'admin.demo_requests.activity.contact_registered',
            channel: contact_channel_label,
            outcome: contact_outcome_label
          )
        )
      end

      if (@demo_request.saved_change_to_next_follow_up_at? || @demo_request.saved_change_to_next_action?) &&
         @demo_request.next_follow_up_at.present?
        @demo_request.activities.create!(
          user: current_user,
          action: 'follow_up_scheduled',
          details: t(
            'admin.demo_requests.activity.follow_up_scheduled',
            date: l(@demo_request.next_follow_up_at, format: :long),
            action: @demo_request.next_action
          )
        )
      end

      if @demo_request.saved_change_to_demo_outcome?
        @demo_request.activities.create!(
          user: current_user,
          action: 'demo_outcome_recorded',
          details: t(
            'admin.demo_requests.activity.demo_outcome_recorded',
            outcome: demo_outcome_label
          )
        )
      end

      return unless @demo_request.saved_change_to_status? && @demo_request.converted?

      @demo_request.activities.create!(
        user: current_user,
        action: 'converted',
        details: t('admin.demo_requests.activity.converted')
      )
    end

    def contact_channel_label
      t("admin.demo_requests.contact_channels.#{@demo_request.contact_channel}")
    end

    def contact_outcome_label
      t("admin.demo_requests.contact_outcomes.#{@demo_request.contact_outcome}")
    end

    def demo_outcome_label
      t("admin.demo_requests.demo_outcomes.#{@demo_request.demo_outcome}")
    end

    def record_note
      note = @demo_request.note.to_s.strip
      return if note.blank?

      @demo_request.activities.create!(
        user: current_user,
        action: 'note_added',
        details: note
      )
      @demo_request.note = nil
    end

    def reset_demo_reminders_if_rescheduled
      return unless @demo_request.saved_change_to_scheduled_at?

      @demo_request.update_columns(reminder_24h_sent_at: nil, reminder_1h_sent_at: nil)
    end

    def schedule_demo_reminders(previous_status)
      return unless @demo_request.scheduled?
      return if @demo_request.scheduled_at.blank?
      return if previous_status == 'scheduled' && !@demo_request.saved_change_to_scheduled_at?

      schedule_reminder('twenty_four_hours', 24.hours)
      schedule_reminder('one_hour', 1.hour)
    end

    def schedule_reminder(window, interval)
      run_at = @demo_request.scheduled_at - interval
      return if run_at <= Time.current

      DemoRequestReminderJob
        .set(wait_until: run_at)
        .perform_later(@demo_request.id, window.to_s, @demo_request.scheduled_at.to_i)
    end

    def send_scheduled_confirmation(previous_status)
      return unless @demo_request.scheduled?
      return if previous_status == 'scheduled' && !@demo_request.saved_change_to_scheduled_at?

      DemoRequestMailer.with(
        demo_request: @demo_request,
        locale: @demo_request.locale
      ).scheduled.deliver_later

      @demo_request.activities.create!(
        user: current_user,
        action: 'confirmation_sent',
        details: I18n.with_locale(@demo_request.locale) do
          I18n.t('demo_request_mailer.scheduled.activity')
        end
      )
    end

    def notify_assignee_of_workflow_change(previous_status, previous_assignee)
      return if @demo_request.assigned_to.blank?
      return if previous_status == @demo_request.status && previous_assignee == @demo_request.assigned_to_id

      action = previous_assignee != @demo_request.assigned_to_id ? 'assigned' : 'status_changed'
      DemoRequestMailer.with(
        demo_request: @demo_request,
        assignee: @demo_request.assigned_to,
        actor: current_user,
        action:,
        locale: @demo_request.assigned_to.language&.code || I18n.locale.to_s
      ).workflow_update.deliver_later
    end

    def record_workflow_activity(previous_status, previous_assignee)
      if previous_status != @demo_request.status
        @demo_request.activities.create!(
          user: current_user,
          action: 'status_changed',
          details: t(
            'admin.demo_requests.activity.status_changed',
            from: status_label(previous_status),
            to: status_label(@demo_request.status)
          )
        )
      end

      return if previous_assignee == @demo_request.assigned_to_id

      @demo_request.activities.create!(
        user: current_user,
        action: 'assigned',
        details: if @demo_request.assigned_to
                   t('admin.demo_requests.activity.assigned_to',
                     user: @demo_request.assigned_to.display_name)
                 else
                   t('admin.demo_requests.activity.unassigned')
                 end
      )
    end

    def status_label(status)
      t("admin.demo_requests.statuses.#{status}")
    end
  end
end
