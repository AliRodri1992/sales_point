# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserStatusMailer, type: :mailer do
  it 'renders a status notice from the centralized template' do
    organization = create(:organization)
    actor = create(:user)
    user = create(:user, status: :suspended)
    event = UserStatusEvent.create!(
      user:, actor:, organization:, from_status: 'active',
      to_status: 'suspended', reason: 'Administrative review'
    )
    mail = described_class.changed(event.id)

    expect(mail.to).to eq([user.email])
    expect(mail.subject).to include('Delta POS')
    expect(mail.html_part.body.decoded).to include(organization.name)
    expect(mail.text_part.body.decoded).to include(organization.name)
    expect(mail.html_part.body.decoded).not_to include('Administrative review')
  end
end
