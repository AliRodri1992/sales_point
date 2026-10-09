# frozen_string_literal: true

class DemoRequestMailer < ApplicationMailer
  def new_request
    @demo_request = params[:demo_request]
    @locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale.to_s

    I18n.with_locale(@locale) do
      mail(
        from: @demo_request.email,
        to: 'ali.rodri.vasquez@gmail.com',
        subject: I18n.t('demo_request_mailer.new_request.subject')
      )
    end
  end

  def workflow_update
    @demo_request = params[:demo_request]
    @assignee = params[:assignee]
    @actor = params[:actor]
    @action = params[:action]
    @locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale.to_s

    I18n.with_locale(@locale) do
      mail(
        to: @assignee.email,
        subject: I18n.t("demo_request_mailer.workflow_update.#{@action}.subject")
      )
    end
  end

  def scheduled
    @demo_request = params[:demo_request]
    @locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale.to_s

    I18n.with_locale(@locale) do
      mail(
        to: @demo_request.email,
        subject: I18n.t('demo_request_mailer.scheduled.subject')
      )
    end
  end

  def reminder(reminder_window)
    @demo_request = params[:demo_request]
    @reminder_window = reminder_window
    @locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale.to_s

    I18n.with_locale(@locale) do
      mail(
        to: @demo_request.email,
        subject: I18n.t("demo_request_mailer.reminder.#{reminder_window}.subject")
      )
    end
  end

  def confirmation
    @demo_request = params[:demo_request]
    @locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale.to_s

    I18n.with_locale(@locale) do
      mail(
        to: @demo_request.email,
        subject: I18n.t('demo_request_mailer.confirmation.subject')
      )
    end
  end
end
