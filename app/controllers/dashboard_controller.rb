# frozen_string_literal: true

class DashboardController < ApplicationController
  layout 'dashboard'

  before_action :authenticate_user!
  before_action :require_delta_user

  def index
    @total_demo_requests = DemoRequest.count
    @pending_demo_requests = DemoRequest.pending.count
    @contacted_demo_requests = DemoRequest.contacted.count
    @completed_demo_requests = DemoRequest.completed.count
    @delta_users = User.delta.count
    @recent_demo_requests = DemoRequest.order(created_at: :desc).limit(5)
  end

  private

  def require_delta_user
    return if current_user.delta?

    head :forbidden
  end
end
