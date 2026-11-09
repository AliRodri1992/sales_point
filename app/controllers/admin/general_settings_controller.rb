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

      update_preference

      if @settings.errors.empty?
        redirect_to admin_general_settings_path, flash: { swal_message: t('admin.general_settings.saved') }
      else
        render :show, status: @stale_preference ? :conflict : :unprocessable_content
      end
    end

    private

    def require_admin!
      head :forbidden unless current_user.admin? && current_organization
    end

    def load_settings
      scope = current_organization.organization_settings
      @settings = scope.active_records.first
      return if @settings

      return head :not_found if scope.exists?

      redirect_to admin_onboarding_path, alert: t('admin.general_settings.missing_configuration')
    end

    def update_preference
      @settings.with_lock do
        if stale_preference?
          @stale_preference = true
          @settings.errors.add(:default_table_page_size, t('admin.general_settings.stale_message'))
          next
        end

        previous_size = @settings.default_table_page_size
        @settings.assign_attributes(settings_params)
        next unless @settings.save(context: :general_settings)
        next if previous_size == @settings.default_table_page_size

        GeneralSettingAuditEvent.create!(
          organization: current_organization, actor: current_user,
          previous_page_size: previous_size, new_page_size: @settings.default_table_page_size
        )
      end
    end

    def stale_preference?
      expected = params[:expected_default_table_page_size].presence
      expected && expected.to_s != @settings.default_table_page_size.to_s
    end

    def settings_params
      params.expect(organization_setting: [:default_table_page_size])
    end
  end
end
