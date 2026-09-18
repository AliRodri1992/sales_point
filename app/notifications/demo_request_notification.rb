# frozen_string_literal: true

class DemoRequestNotification < Noticed::Base
  deliver_by :email,
             mailer: 'DemoRequestMailer',
             method: :new_request

  param :demo_request
  param :locale
end
