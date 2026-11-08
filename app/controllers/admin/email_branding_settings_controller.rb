# frozen_string_literal: true

module Admin
  class EmailBrandingSettingsController < ApplicationController
    include EmailSettingActivity

    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      verify_permission!
      @branding = EmailBrandingSetting.find_or_initialize_by(organization: selected_organization)
      @audits = EmailSettingAudit.where(organization: selected_organization, setting_type: 'branding')
                                 .includes(:actor).order(created_at: :desc).limit(20)
    end

    def update
      verify_permission!
      @branding = EmailBrandingSetting.find_or_initialize_by(organization: selected_organization)
      attributes = branding_params
      remove_logo = should_remove_logo?(attributes)
      return render_branding_errors unless save_branding(attributes, remove_logo:)

      @branding.logo.purge_later if remove_logo
      notify_email_setting('branding_updated', @branding)
      redirect_to edit_admin_email_branding_settings_path,
                  flash: { swal_message: t('admin.email_templates.saved') }
    end

    private

    def should_remove_logo?(attributes)
      params[:remove_logo] == '1' && attributes[:logo].blank? && @branding.logo.attached?
    end

    def save_branding(attributes, remove_logo:)
      EmailBrandingSetting.transaction do
        next false unless @branding.update(attributes)

        extra = {}
        extra['logo_updated'] = true if attributes.key?(:logo)
        extra['logo_removed'] = true if remove_logo
        EmailSettingAudit.record!(setting: @branding, actor: current_user, kind: 'branding', extra:)
        true
      end
    end

    def render_branding_errors
      @audits = EmailSettingAudit.where(organization: selected_organization, setting_type: 'branding')
                                 .includes(:actor).order(created_at: :desc).limit(20)
      render :edit, status: :unprocessable_content
    end

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
