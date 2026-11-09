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
      expect(html).to include('delta-pos-email-logo')
      expect(html).to include('example.org/activation-demo')
      expect(plain).to include('activation-demo')
    end
  end

  it 'applies organization button colors to both CSS and email-client fallback attributes' do
    EmailTemplates::InvitationContent.ensure_published!
    invitation = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')
    values = EmailTemplates::SampleData.call(invitation).merge(button_color: '#135724')

    _subject, html, _plain = invitation.render_with(values)
    document = Nokogiri::HTML.fragment(html)

    expect(document.at_css('td[bgcolor]')['bgcolor']).to eq('#135724')
    expect(html).to include('background-color:#135724')
    expect(html).not_to include('background-color:{{primary_color}}')
  end

  it 'does not replace customized published invitation versions' do
    EmailTemplates::InvitationContent.ensure_published!
    built_in = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')
    draft = built_in.new_draft!(actor: nil)
    draft.update!(
      subject: 'Edited invitation', preheader: '',
      html_body: '<p>{{invited_name}}</p><a href="{{activation_url}}">Accept</a>',
      text_body: '{{invited_name}} {{activation_url}}', allowed_variables: %w[invited_name activation_url]
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

      expect(values.fetch(:platform_logo)).to include('delta-pos-email-logo')
      expect(values.fetch(:logo_url)).to include('delta-pos-email-logo')
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

  it 'renders security test mail in production without actionable example-domain links' do
    EmailTemplates::InvitationContent.ensure_published!
    invitation = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DELTA_POS_PUBLIC_HOST').and_return('mail.delta.test')

    message = EmailTemplateTestMailer.sample(invitation.id, 'preview@example.org').message
    document = Nokogiri::HTML(message.html_part.body.decoded)

    expect(message.subject).to start_with('[TEST]')
    expect(document.css('a[href*="example.org"]')).to be_empty
    expect(message.text_part.body.decoded).not_to include('https://example.org/activation-demo')
  end

  it 'rejects test delivery after a template is deactivated' do
    publish
    template.update!(status: 'inactive', enabled: false)
    expect do
      EmailTemplateTestMailer.sample(template.id, 'preview@example.org').message
    end.to raise_error(ArgumentError, 'Template must be published')
  end

  it 'does not send preview mail from unpublished content' do
    expect do
      EmailTemplateTestMailer.sample(template.id, 'preview@example.org').message
    end.to raise_error(ArgumentError, 'Template must be published')
  end

  it 'renders the original version when a newer published version exists' do
    publish
    first = template.published_version
    next_draft = template.new_draft!(actor: nil)
    next_draft.update!(subject: 'Updated {{recipient_name}}')
    next_draft.publish!(actor: nil)

    mail = EmailTemplates::TransactionalMailer.notification(
      template.id, 'buyer@example.org', { recipient_name: 'Buyer' }, nil, first.id
    ).message

    expect(mail.subject).to eq('Hello Buyer')
    expect(template.reload.published_version_id).not_to eq(first.id)
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

  it 'resolves branding placeholders even without caller-provided color variables' do
    organization = create(:organization)
    template.update!(organization:)
    template.update!(html_body: '<p>{{primary_color}}</p>')
    template.new_draft!(actor: nil).publish!(actor: nil)
    _, html, = EmailTemplates::Resolver.call(
      key: template.key, locale: 'es', organization:, values: { recipient_name: 'Buyer' }
    )
    expect(html).to include('#064e3b')
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

  it 'uses a verified Reply-To address on transactional delivery' do
    organization = create(:organization)
    template.update!(organization:)
    EmailSenderSetting.create!(
      organization:, display_name: 'Store', from_address: 'noreply@shop.test',
      reply_to: 'support@shop.test', domain: 'shop.test', domain_status: 'verified'
    )
    publish
    message = EmailTemplates::TransactionalMailer.notification(
      template.id, 'buyer@example.org', { recipient_name: 'Buyer' }, organization.id
    ).message

    expect(message.reply_to).to eq(['support@shop.test'])
    expect(message.from).to eq(['noreply@shop.test'])
  end
end
