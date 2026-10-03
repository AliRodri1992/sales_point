# frozen_string_literal: true

module Admin
  class OnboardingController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def show
      authorize :onboarding, :show?
      @organization = current_user.organizations.active_records.first
      @progress = Onboarding::ProgressCalculator.call(@organization)
    end
  end
end