# frozen_string_literal: true

module Admin
  class OrganizationSelectionsController < ApplicationController
    before_action :authenticate_user!

    def update
      organization = available_organizations.find(params[:id])
      session[:current_organization_id] = organization.id
      session.delete(:current_branch_id)

      redirect_to admin_dashboard_path
    end
  end
end
