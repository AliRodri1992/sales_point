# frozen_string_literal: true

module Admin
  class EmailSenderSettingsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      verify_permission!
      @sender = EmailSenderSetting.find_or_initialize_by(organization: current_organization)
      @audits = EmailSettingAudit.where(organization: current_organization, setting_type: 'sender')
                                .includes(:actor).order(created_at: :desc).limit(20)
    end

    def update
      verify_permission!
      @sender = EmailSenderSetting.find_or_initialize_by(organization: current_organization)
      EmailSenderSetting.transaction do
        if @sender.update(sender_params)
          EmailSettingAudit.record!(setting: @sender, actor: current_user, kind: 'sender')
          redirect_to edit_admin_email_sender_settings_path, notice: t('admin.email_templates.saved')
        else
          @audits = EmailSettingAudit.where(organization: current_organization, setting_type: 'sender')
                                    .includes(:actor).order(created_at: :desc).limit(20)
          render :edit, status: :unprocessable_content
        end
      end
    end

    private

    def verify_permission!
      allowed = current_organization && current_user.admin? && current_user.permission?('email_settings.manage')
      raise Pundit::NotAuthorizedError unless allowed
    end

    def sender_params
      params.expect(email_sender_setting: %i[display_name from_address reply_to default_locale])
    end
  end
end
