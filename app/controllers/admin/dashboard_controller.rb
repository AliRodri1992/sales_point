class Admin::DashboardController < ApplicationController
  layout 'admin_dashboard'
  before_action :authenticate_user!

  def index
  end
end
