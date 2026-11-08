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
    end
    described_class.call(
      key: template.key, locale: template.locale,
      recipient: 'secret.person@example.org', values: { recipient_name: 'Example' }
    )
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
