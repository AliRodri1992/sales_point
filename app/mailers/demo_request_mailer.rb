# frozen_string_literal: true

class DemoRequestMailer < ApplicationMailer
  def new_request
    @demo_request = params[:demo_request]

    mail(
      from: @demo_request.email,
      to: 'ali.rodri.vasquez@gmail.com',
      subject: 'Nueva solicitud de demostración - Nexo POS'
    )
  end
end
