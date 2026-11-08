# frozen_string_literal: true

module Admin
  class EmailSenderSettingsController < ApplicationController
    include EmailSettingActivity

    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      verify_permission!
      @sender = EmailSenderSetting.find_or_initialize_by(organization: current_organization)
      load_sender_editor
    end

    def update
      verify_permission!
      @sender = EmailSenderSetting.find_or_initialize_by(organization: current_organization)
      saved = EmailSenderSetting.transaction do
        next false unless @sender.update(sender_params)

        EmailSettingAudit.record!(setting: @sender, actor: current_user, kind: 'sender')
        true
      end
      if saved
        notify_email_setting('sender_updated', @sender)
        redirect_to edit_admin_email_sender_settings_path,
                    flash: { swal_message: t('admin.email_templates.saved') }
      else
        render_sender_errors
      end
    end

    private

    def render_sender_errors
      load_sender_editor
      render :edit, status: :unprocessable_content
    end

    def load_sender_editor
      @sender_ready = EmailTemplates::Sender.verified?(@sender)
      global = EmailSenderSetting.find_by(organization_id: nil)
      @global_sender_ready = EmailTemplates::Sender.verified?(global)
      @audits = EmailSettingAudit.where(organization: current_organization, setting_type: 'sender')
                                 .includes(:actor).order(created_at: :desc).limit(20)
    end

    def verify_permission!
      allowed = current_organization && current_user.admin? && current_user.permission?('email_settings.manage')
      raise Pundit::NotAuthorizedError unless allowed
    end

    def sender_params
      params.expect(email_sender_setting: %i[display_name from_address reply_to default_locale])
    end
  end
end
