# frozen_string_literal: true

class DemoRequestNotification < Noticed::Event
  deliver_by :email,
             mailer: 'DemoRequestMailer',
             method: :new_request

  required_param :demo_request
  required_param :locale
end
