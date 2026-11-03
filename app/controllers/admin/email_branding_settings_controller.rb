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
      attributes = branding_params
      EmailBrandingSetting.transaction do
        if @branding.update(attributes)
          extra = attributes.key?(:logo) ? { 'logo_updated' => true } : {}
          EmailSettingAudit.record!(setting: @branding, actor: current_user, kind: 'branding', extra:)
          redirect_to edit_admin_email_branding_settings_path, notice: t('admin.email_templates.saved')
        else
          render :edit, status: :unprocessable_content
        end
      end
    end

    private

    def selected_organization
      params[:global] == '1' && current_user.role?('super_admin') ? nil : current_organization
    end

    def verify_permission!
      permission = selected_organization ? 'email_branding.manage' : 'email_settings.manage'
      allowed = (selected_organization || current_user.role?('super_admin')) &&
                current_user.admin? && current_user.permission?(permission)
      raise Pundit::NotAuthorizedError unless allowed
    end

    def branding_params
      keys = %i[display_name primary_color secondary_color button_color support_email
                support_url privacy_url footer_text logo]
      params.expect(email_branding_setting: keys)
    end
  end
end
