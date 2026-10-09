# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestNotification, type: :notification do
  let(:demo_request) { create(:demo_request) }

  it 'delivers one email notification with the demo request data' do
    mail = DemoRequestMailer.with(demo_request:, locale: 'en').new_request

    expect(mail.to).to eq(['ali.rodri.vasquez@gmail.com'])
    expect(mail.subject).to eq('New demo request - Delta POS')
    expect(mail.from).to eq([demo_request.email])
    expect(mail.html_part.body.to_s).to include(demo_request.name, demo_request.company)
  end
end
