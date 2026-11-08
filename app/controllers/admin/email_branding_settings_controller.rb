# frozen_string_literal: true

module Admin
  class EmailBrandingSettingsController < ApplicationController
    include EmailSettingActivity

    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      @branding = EmailBrandingSetting.find_or_initialize_by(organization: selected_organization)
      authorize @branding, :edit?
      load_branding_audits
    end

    def update
      @branding = EmailBrandingSetting.find_or_initialize_by(organization: selected_organization)
      authorize @branding, :update?
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
      load_branding_audits
      render :edit, status: :unprocessable_content
    end

    def selected_organization
      params[:global] == '1' && current_user.role?('super_admin') ? nil : current_organization
    end

    def load_branding_audits
      @can_view_audits = policy(EmailSettingAudit).index?
      @audits = if @can_view_audits
                  policy_scope(EmailSettingAudit).where(organization: selected_organization, setting_type: 'branding')
                                                 .includes(:actor).order(created_at: :desc).limit(20)
                else
                  []
                end
    end

    def branding_params
      keys = %i[display_name primary_color secondary_color button_color support_email
                support_url privacy_url footer_text logo]
      params.expect(email_branding_setting: keys)
    end
  end
end
