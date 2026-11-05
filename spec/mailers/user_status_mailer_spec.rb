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
  it 'uses a verified organization sender for a status message' do
    organization = create(:organization)
    actor = create(:user)
    user = create(:user, status: :suspended)
    EmailSenderSetting.create!(
      organization:, display_name: 'Delta POS',
      from_address: 'notificaciones@delta.test',
      domain: 'delta.test', domain_status: 'verified', default_locale: 'es'
    )
    event = UserStatusEvent.create!(
      user:, actor:, organization:, from_status: 'active',
      to_status: 'suspended', reason: 'Administrative review'
    )

    mail = described_class.changed(event.id)

    expect(mail.from).to eq(['notificaciones@delta.test'])
  end

  it 'uses the account language for a localized status message' do
    organization = create(:organization)
    user = create(:user, :english)
    event = UserStatusEvent.create!(
      user:, actor: create(:user), organization:, from_status: 'active', to_status: 'suspended', reason: 'Review'
    )
    email = described_class.changed(event.id)
    expect(email.text_part.body.decoded).to include(I18n.t('admin.users.statuses.suspended', locale: :en))
    expect(EmailTemplate.resolve(key: 'user_status_changed', locale: 'en', organization:)).to be_present
  end
end
