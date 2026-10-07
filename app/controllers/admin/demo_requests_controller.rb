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
      @filters = DemoRequests::Filters.new(params, current_user)
      @demo_requests = @filters.call
      @total_count = @demo_requests.except(:limit, :offset).count
      @users = User.active.where(user_type: :employee)
                   .order(Arel.sql('COALESCE(username, email) ASC'))
      @metrics = @filters.metrics

      # Extract pagination info from filtered scope
      @per_page = [params[:per_page].to_i, 5, 10, 15].max
      total = @demo_requests.except(:limit, :offset).count
      @total_pages = [total / @per_page.to_f, 1].max.ceil
      @current_page = params[:page].to_i.clamp(1, [@total_pages, 1].max)
    end

    def show
      authorize @demo_request
      @users = User.active.where(user_type: :employee)
                   .order(Arel.sql('COALESCE(username, email) ASC'))
      @activities = @demo_request.activities.includes(:user).order(created_at: :desc)
    end

    def update
      authorize @demo_request

      previous_status = @demo_request.status
      previous_assignee = @demo_request.assigned_to_id

      if @demo_request.update(demo_request_params)
        handle_successful_update(previous_status, previous_assignee)
      else
        handle_failed_update
      end
    end

    def handle_successful_update(previous_status, previous_assignee)
      DemoRequests::Workflow.new(
        @demo_request,
        current_user,
        previous_status,
        previous_assignee
      ).call

      redirect_to admin_demo_request_path(@demo_request),
                  notice: t('admin.demo_requests.updated')
    end

    def handle_failed_update
      @users = User.active.where(user_type: :employee)
                   .order(Arel.sql('COALESCE(username, email) ASC'))
      @activities = @demo_request.activities.includes(:user).order(created_at: :desc)
      render :show, status: :unprocessable_content
    end

    private

    def set_demo_request
      @demo_request = DemoRequest.find(params[:id])
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
  end
end
