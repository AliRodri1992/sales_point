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
        record_note
        schedule_demo_reminders(previous_status)
        send_scheduled_confirmation(previous_status)
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
      @demo_requests = scope.order(created_at: :desc)
                            .limit(@per_page)
                            .offset((@current_page - 1) * @per_page)
    end

    def active_users
      User.active.where(user_type: :employee).order(Arel.sql("COALESCE(username, email) ASC"))
    end

    def per_page_param
      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def demo_request_params
      params.expect(demo_request: %i[status assigned_to_id scheduled_at note])
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

      DemoRequestReminderJob.set(wait_until: run_at).perform_later(@demo_request.id, window.to_s)
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
        action: 'status_changed',
        details: I18n.with_locale(@demo_request.locale) do
          I18n.t('demo_request_mailer.scheduled.activity')
        end
      )
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
