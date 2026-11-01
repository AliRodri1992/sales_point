# frozen_string_literal: true

module Admin
  class GeneralSettingsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_admin!

    def show
      load_settings
    end

    def update
      load_settings
      return if performed?

      if @settings.update(settings_params)
        redirect_to admin_general_settings_path, flash: { swal_message: t('admin.general_settings.saved') }
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def require_admin!
      head :forbidden unless current_user.admin? && current_organization
    end

    def load_settings
      @settings = current_organization.organization_settings.active_records.first
      head :not_found unless @settings
    end

    def settings_params
      params.expect(organization_setting: [:default_table_page_size])
    end
  end
end
