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
end
