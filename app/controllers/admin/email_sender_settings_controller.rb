# frozen_string_literal: true

module Admin
  class EmailSenderSettingsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def edit
      verify_permission!
      @sender = EmailSenderSetting.find_or_initialize_by(organization: current_organization)
    end

    def update
      verify_permission!
      @sender = EmailSenderSetting.find_or_initialize_by(organization: current_organization)
      if @sender.update(sender_params)
        redirect_to edit_admin_email_sender_settings_path, notice: t('admin.email_templates.saved')
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def verify_permission!
      raise Pundit::NotAuthorizedError unless current_user.admin? && current_user.permission?('email_settings.manage')
    end

    def sender_params
      params.expect(email_sender_setting: %i[display_name from_address reply_to default_locale])
    end
  end
end
