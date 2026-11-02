# frozen_string_literal: true

class PrivacyController < ApplicationController
  def show
    @privacy_identity = ENV.fetch('DELTA_POS_PRIVACY_RESPONSIBLE', 'Kurosoft S.A. de C.V.').strip
    @privacy_contact_name = ENV.fetch('DELTA_POS_PRIVACY_CONTACT_NAME', 'Ivan Ali Rodriguez Vasquez').strip
    @privacy_address = ENV.fetch('DELTA_POS_PRIVACY_ADDRESS', 'Privada Condominio Nispero Casa 25').strip
    contact = ENV.fetch('DELTA_POS_PRIVACY_EMAIL', '').strip
    @privacy_email = contact if contact.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
