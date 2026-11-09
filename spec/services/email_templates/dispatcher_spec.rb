# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Dispatcher do
  let(:template) do
    EmailTemplate.create!(
      key: 'generic_notice', name: 'Generic', locale: 'es',
      category: 'transactional', status: 'published',
      subject: 'Hello {{recipient_name}}',
      html_body: '<p>{{recipient_name}}</p>',
      text_body: '{{recipient_name}}'
    )
  end

  before do
    version = template.versions.create!(
      version_number: 1, status: 'published',
      subject: template.subject, html_body: template.html_body,
      text_body: template.text_body, allowed_variables: %w[recipient_name]
    )
    template.update!(published_version: version)
  end

  it 'encrypts personally identifying arguments before enqueuing' do
    expect(EmailTemplates::DeliveryJob).to receive(:perform_later) do |ciphertext|
      expect(ciphertext).not_to include('secret.person@example.org')
      data = EmailTemplates::EncryptedPayload.decrypt(ciphertext)
      expect(data[:recipient]).to eq('secret.person@example.org')
      expect(data[:version_id]).to eq(template.published_version_id)
      expect(data[:sender_headers]).to eq({})
    end
    described_class.call(
      key: template.key, locale: template.locale,
      recipient: 'secret.person@example.org', values: { recipient_name: 'Example' }
    )
  end
  it 'uses the configured sender locale when the caller does not provide one' do
    organization = create(:organization)
    EmailSenderSetting.create!(organization:, from_address: 'notice@tenant.example', default_locale: 'en')
    en = EmailTemplate.create!(
      key: template.key, name: 'Generic English', locale: 'en', category: 'transactional',
      subject: 'English', html_body: '<p>English</p>', text_body: 'English', status: 'draft'
    )
    en.new_draft!(actor: nil).publish!(actor: nil)

    expect(EmailTemplates::DeliveryJob).to receive(:perform_later) do |ciphertext|
      payload = EmailTemplates::EncryptedPayload.decrypt(ciphertext)
      expect(payload[:template_id]).to eq(en.id)
    end

    described_class.call(key: template.key, recipient: 'buyer@example.org', values: {}, organization:)
  end

  it 'encrypts the selected verified sender for delivery' do
    organization = create(:organization)
    EmailSenderSetting.create!(
      organization:, from_address: 'notice@tenant.example',
      domain: 'tenant.example', domain_status: 'verified'
    )
    expect(EmailTemplates::DeliveryJob).to receive(:perform_later) do |ciphertext|
      payload = EmailTemplates::EncryptedPayload.decrypt(ciphertext)
      expect(payload[:sender_headers][:from]).to include('notice@tenant.example')
    end

    described_class.call(key: template.key, locale: 'es', recipient: 'buyer@example.org',
                         values: { recipient_name: 'Buyer' }, organization:)
  end

  it 'refuses to enqueue legacy published templates with unconfigured contact links in production' do
    version = template.versions.create!(
      version_number: 2, status: 'published', subject: 'Contact',
      html_body: '<p>{{support_email}}</p>', text_body: '{{support_email}}',
      allowed_variables: %w[support_email]
    )
    template.update!(published_version: version)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DELTA_POS_PUBLIC_HOST').and_return('mail.delta.test')

    expect(EmailTemplates::DeliveryJob).to receive(:perform_later).once
    expect do
      described_class.call(key: template.key, locale: 'es', recipient: 'customer@delta.test', values: {})
    end.to raise_error(ArgumentError, /Unconfigured email contacts: support_email/)

    EmailBrandingSetting.create!(display_name: 'Global',
                                 support_email: 'help@delta.test')
    described_class.call(key: template.key, locale: 'es', recipient: 'customer@delta.test', values: {})
  end

  it 'uses organization branding even when the global template is selected' do
    organization = create(:organization)
    expect(EmailTemplates::Branding).to receive(:values).with(organization:).and_call_original
    allow(EmailTemplates::DeliveryJob).to receive(:perform_later)

    described_class.call(
      key: template.key, locale: template.locale, organization:,
      recipient: 'example@example.org', values: { recipient_name: 'Example' }
    )
  end
end
