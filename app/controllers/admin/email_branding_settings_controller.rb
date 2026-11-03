# frozen_string_literal: true

module Admin
  class EmailBrandingSettingsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      verify_permission!
      @branding = EmailBrandingSetting.find_or_initialize_by(organization: selected_organization)
    end

    def update
      verify_permission!
      @branding = EmailBrandingSetting.find_or_initialize_by(organization: selected_organization)
      if @branding.update(branding_params)
        redirect_to edit_admin_email_branding_settings_path, notice: t('admin.email_templates.saved')
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def selected_organization
      params[:global] == '1' && current_user.role?('super_admin') ? nil : current_organization
    end

    def verify_permission!
      permission = selected_organization ? 'email_branding.manage' : 'email_settings.manage'
      raise Pundit::NotAuthorizedError unless current_user.admin? && current_user.permission?(permission)
    end

    def branding_params
      params.expect(email_branding_setting: %i[display_name primary_color secondary_color button_color
                                              support_email support_url privacy_url footer_text logo])
    end
  end
end
