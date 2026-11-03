# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::TestDelivery do
  let(:actor) { create(:user) }
  let(:template) do
    EmailTemplate.create!(
      key: 'test_notice', name: 'Test notice', category: 'security',
      locale: 'es', subject: 'Test', html_body: '<p>Test</p>',
      text_body: 'Test', status: 'published'
    )
  end

  before do
    version = template.versions.create!(
      version_number: 1, status: 'published', subject: 'Test',
      html_body: '<p>Test</p>', text_body: 'Test'
    )
    template.update!(published_version: version)
  end

  it 'rejects sending tests to an unrelated email address' do
    expect do
      described_class.call(template:, actor:, recipient: 'other@example.org')
    end.to raise_error(Pundit::NotAuthorizedError)
    expect(template.audits.count).to eq(0)
  end

  it 'caps attempts to three per hour' do
    3.times { template.audit!(action: 'test_sent', actor:) }
    expect do
      described_class.call(template:, actor:, recipient: actor.email)
    end.to raise_error(ArgumentError, /limit/)
  end
end
