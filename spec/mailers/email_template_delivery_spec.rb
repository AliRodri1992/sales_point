# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Published email template delivery', type: :mailer do
  let(:template) do
    EmailTemplate.create!(
      key: 'receipt', name: 'Receipt', locale: 'es', category: 'transactions',
      subject: 'Hello {{recipient_name}}', html_body: '<p>{{recipient_name}}</p>',
      text_body: '{{recipient_name}}', status: 'draft'
    )
  end

  def publish
    template.new_draft!(actor: nil).publish!(actor: nil)
  end

  it 'publishes localized built-in invitations with the complete Delta POS logo' do
    EmailTemplates::InvitationContent.ensure_published!
    %w[es en ko].each do |locale|
      built_in = EmailTemplate.global.find_by!(key: 'user_invitation', locale:)
      expect(built_in.published_version).to be_present
      subject, html, plain = built_in.render_with(
        EmailTemplates::SampleData.call(built_in)
      )
      expect(subject).to be_present
      expect(html).to include('LOGOTIPO')
      expect(html).to include('example.org/activation-demo')
      expect(plain).to include('activation-demo')
    end
  end

  it 'does not replace customized published invitation versions' do
    EmailTemplates::InvitationContent.ensure_published!
    built_in = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')
    draft = built_in.new_draft!(actor: nil)
    draft.update!(
      subject: 'Edited invitation', html_body: '<p>{{invited_name}}</p>',
      text_body: '{{invited_name}}', allowed_variables: ['invited_name']
    )
    draft.publish!(actor: nil)

    expect { EmailTemplates::InvitationContent.ensure_published! }
      .not_to(change { built_in.reload.published_version_id })
    expect(built_in.subject).to eq('Edited invitation')
  end

  it 'uses the actual Delta POS logo and localizes sample names on previews' do
    expected_names = { 'es' => 'Usuario de ejemplo', 'en' => 'Sample user', 'ko' => '예시 사용자' }
    %w[es en ko].each do |locale|
      sample_template = EmailTemplate.new(locale:)
      values = EmailTemplates::SampleData.call(sample_template)

      expect(values.fetch(:platform_logo)).to include('LOGOTIPO')
      expect(values.fetch(:logo_url)).to include('LOGOTIPO')
      expect(values.fetch(:recipient_name)).to eq(expected_names.fetch(locale))
    end
  end

  it 'delivers a preview using sample data and marks its subject as a test' do
    publish
    email = EmailTemplateTestMailer.sample(template.id, 'preview@example.org')
    expect(email.to).to eq(['preview@example.org'])
    expect(email.subject).to start_with('[TEST] Hello ')
    expect(email.html_part.body.decoded).to include('Usuario de ejemplo')
    expect(email.text_part.body.decoded).to include('Usuario de ejemplo')
  end

  it 'does not send preview mail from unpublished content' do
    expect do
      EmailTemplateTestMailer.sample(template.id, 'preview@example.org').message
    end.to raise_error(ArgumentError, 'Template must be published')
  end

  it 'decrypts queued payloads and delivers both message parts' do
    publish
    encrypted = EmailTemplates::EncryptedPayload.encrypt(
      template_id: template.id, recipient: 'buyer@example.org', values: { recipient_name: 'Buyer' }
    )
    expect { EmailTemplates::DeliveryJob.perform_now(encrypted) }
      .to change(ActionMailer::Base.deliveries, :count).by(1)
    email = ActionMailer::Base.deliveries.last
    expect(email.subject).to eq('Hello Buyer')
    expect(email.text_part.body.decoded).to eq('Buyer')
    expect(email.html_part.body.decoded).to include('Buyer')
  end

  it 'rejects legacy published templates without a version snapshot' do
    template.update!(status: 'published')
    expect do
      EmailTemplates::TransactionalMailer.notification(template.id, 'buyer@example.org', {}).message
    end.to raise_error(ArgumentError, 'Template has no published version')
  end

  it 'resolves published content and rejects a missing template' do
    publish
    rendered = EmailTemplates::Resolver.call(
      key: template.key, locale: 'es', values: { recipient_name: 'Buyer' }
    )
    expect(rendered.first).to eq('Hello Buyer')
    expect do
      EmailTemplates::Resolver.call(key: 'missing', locale: 'es', values: {})
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'rejects dispatch to invalid recipients or missing template snapshots' do
    expect do
      EmailTemplates::Dispatcher.call(key: 'missing', locale: 'es', recipient: 'buyer@example.org', values: {})
    end.to raise_error(ActiveRecord::RecordNotFound)
    template.update!(status: 'published')
    expect do
      EmailTemplates::Dispatcher.call(key: template.key, locale: 'es', recipient: 'buyer@example.org', values: {})
    end.to raise_error(ActiveRecord::RecordNotFound)
    publish
    expect do
      EmailTemplates::Dispatcher.call(key: template.key, locale: 'es', recipient: 'invalid', values: {})
    end.to raise_error(ArgumentError, 'Invalid recipient')
  end
end
