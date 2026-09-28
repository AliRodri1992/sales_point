# frozen_string_literal: true

module Admin
  class OrganizationsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_organization, only: %i[show edit update]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    def index
      authorize Organization
      @organizations = policy_scope(Organization)
                       .includes(subscription: :membership_plan)
                       .order(:name)
    end

    def show
      authorize @organization
    end

    def new
      @organization = Organization.new(status: 'active')
      authorize @organization
    end

    def create
      @organization = Organization.new(organization_params)
      authorize @organization

      if @organization.save
        notify_organization('created')
        redirect_to admin_organization_path(@organization),
                    flash: { swal_message: t('admin.organizations.created') }
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @organization
    end

    def update
      authorize @organization

      if @organization.update(organization_params)
        notify_organization('updated')
        redirect_to admin_organization_path(@organization),
                    flash: { swal_message: t('admin.organizations.updated') }
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_organization
      @organization = policy_scope(Organization).find(params[:id])
    end

    def organization_params
      params.expect(
        organization: %i[name code legal_name tax_id email phone status]
      )
    end

    def notify_organization(action)
      OrganizationNotification.with(action:, record: @organization, user: current_user)
                              .deliver(current_user, enqueue_job: false)
      current_user.broadcast_notifications_refresh
    end

    def forbidden
      head :forbidden
    end
  end
end
