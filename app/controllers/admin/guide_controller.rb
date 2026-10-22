# frozen_string_literal: true

module Admin
  class GuideController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def show
      @topics = %w[profile suppliers contacts addresses products documents schedules finances purchases reports]
    end
  end
end
