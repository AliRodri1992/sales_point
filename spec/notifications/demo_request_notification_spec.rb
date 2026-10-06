# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestNotification, type: :notification do
  let(:demo_request) { build(:demo_request) }

  before do
    ActionMailer::Base.deliveries.clear
  end

  it 'delivers one email notification with the demo request data' do
    expect do
      described_class.with(
        demo_request:,
        locale: 'en'
      ).deliver(demo_request, enqueue_job: false)
    end.to change(ActionMailer::Base.deliveries, :size).by(1)

    mail = ActionMailer::Base.deliveries.last

    expect(mail.to).to eq(['ali.rodri.vasquez@gmail.com'])
    expect(mail.subject).to eq('New demo request - Delta POS')
    expect(mail.html_part.body.to_s).to include(demo_request.name, demo_request.company)
  end
end
