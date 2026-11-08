# frozen_string_literal: true

module Admin
  class EmailSenderSettingsController < ApplicationController
    include EmailSettingActivity

    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      @sender = EmailSenderSetting.find_or_initialize_by(organization: selected_organization)
      authorize @sender, :edit?
      load_sender_editor
    end

    def update
      @sender = EmailSenderSetting.find_or_initialize_by(organization: selected_organization)
      authorize @sender, :update?
      saved = EmailSenderSetting.transaction do
        next false unless @sender.update(sender_params)

        EmailSettingAudit.record!(setting: @sender, actor: current_user, kind: 'sender')
        true
      end
      if saved
        notify_email_setting('sender_updated', @sender)
        destination = selected_organization.nil? ? edit_admin_email_sender_settings_path(global: '1') :
                                                edit_admin_email_sender_settings_path
        redirect_to destination,
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
      @can_view_audits = policy(EmailSettingAudit).index?
      @audits = if @can_view_audits
                  policy_scope(EmailSettingAudit).where(organization: selected_organization, setting_type: 'sender')
                                                 .includes(:actor).order(created_at: :desc).limit(20)
                else
                  []
                end
    end

    def selected_organization
      params[:global] == '1' && current_user.role?('super_admin') ? nil : current_organization
    end

    def sender_params
      params.expect(email_sender_setting: %i[display_name from_address reply_to default_locale])
    end
  end
end
