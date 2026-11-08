# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserInvitationMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending) }
  let(:invitation) { UserInvitation.issue!(user:, organization:) }

  before do
    create(:organization_membership, user:, organization:, account_status: :pending)
  end

  def deliver(token = invitation.raw_token)
    encrypted = Users::InvitationDeliveryToken.encrypt(token)
    described_class.invite(invitation.id, encrypted).deliver_now
  end

  it 'delivers a secure multipart invitation and records delivery' do
    invitation
    expect { deliver }.to change(ActionMailer::Base.deliveries, :count).by(1)
    email = ActionMailer::Base.deliveries.last
    expect(email.to).to eq([user.email])
    html = email.html_part.body.decoded
    expect(html).to include('https://example.com/invitations/accept')
    expect(html).to include('Crear mi contraseña')
    expect(html).to include('delta-pos-email-logo')
    expect(html).to include('width="320"')
    expect(html).to include(organization.name)
    expect(html).to include(user.email)
    expect(email.text_part.body.decoded).to include(organization.name)
    expect(email.text_part.body.decoded).to include('Crear mi contraseña')
    expect(invitation.reload).to have_attributes(delivery_status: 'sent')
    expect(invitation.sent_at).to be_present
  end

  it 'uses the user language when a localized invitation is published' do
    user.update!(language: create(:language, :english))
    deliver
    template = EmailTemplate.resolve(key: 'user_invitation', locale: 'en', organization:)
    expect(ActionMailer::Base.deliveries.last.subject).to include(organization.name)
    expect(template).to be_present
    expect(ActionMailer::Base.deliveries.last.html_part.body.decoded).to include('Create my password')
  end

  it 'keeps the activation token out of the subject and only renders it in the links' do
    token = invitation.raw_token
    deliver
    email = ActionMailer::Base.deliveries.last
    expect(email.subject).not_to include(token)
    expect(email.text_part.body.decoded).to include(token)
    expect(email.html_part.body.decoded).to include('72')
  end

  it 'preserves a custom published organization invitation' do
    EmailTemplates::InvitationContent.ensure_published!
    original = EmailTemplate.resolve(key: 'user_invitation', locale: 'es', organization:)
    custom = EmailTemplate.create!(
      organization:, key: 'user_invitation', locale: 'es', name: 'Custom invitation',
      category: 'security', status: 'draft', enabled: false,
      subject: 'Personal invitation', html_body: '<p>Custom {{invited_name}}</p>',
      text_body: 'Custom {{invited_name}}'
    )
    custom.new_draft!(actor: nil).publish!(actor: nil)

    deliver
    expect(ActionMailer::Base.deliveries.last.subject).to eq('Personal invitation')
    expect(original.reload.published_version).to be_present
  end

  it 'does not deliver a revoked invitation' do
    token = invitation.raw_token
    invitation.update!(revoked_at: Time.current)
    expect { deliver(token) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(invitation.reload.delivery_status).not_to eq('sent')
  end

  it 'does not deliver a token that does not match the invitation' do
    invitation
    expect { deliver('another token') }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(invitation.reload.delivery_status).not_to eq('sent')
  end

  it 'marks delivery as failed and propagates configuration failures' do
    invitation
    allow(EmailTemplates::Sender).to receive(:headers_for).and_raise(ArgumentError, 'Sender unavailable')
    expect { deliver }.to raise_error(ArgumentError, 'Sender unavailable')
    expect(invitation.reload.delivery_status).to eq('failed')
  end

  it 'rejects malformed encrypted tokens without sending a message' do
    invitation
    expect do
      described_class.invite(invitation.id, 'not-encrypted').deliver_now
    end.to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    expect(invitation.reload.delivery_status).not_to eq('sent')
  end

  it 'propagates a removed invitation without hiding the original error' do
    encrypted = Users::InvitationDeliveryToken.encrypt('removed-token')
    expect do
      described_class.invite(-1, encrypted).deliver_now
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
