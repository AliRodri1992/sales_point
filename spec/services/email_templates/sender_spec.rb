# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Sender do
  let(:organization) { create(:organization) }

  it 'uses only a verified sender whose address matches its domain' do
    EmailSenderSetting.create!(
      organization:, from_address: 'notificaciones@delta.test',
      reply_to: 'soporte@delta.test', domain: 'delta.test',
      domain_status: 'verified', display_name: 'Delta POS', default_locale: 'es'
    )

    headers = described_class.headers_for(organization:)

    expect(headers[:from]).to include('notificaciones@delta.test')
    expect(headers[:reply_to]).to eq('soporte@delta.test')
  end

  it 'rejects unverified or mismatched tenant sender domains' do
    EmailSenderSetting.create!(
      organization:, from_address: 'notificaciones@delta.test',
      domain: 'example.org', domain_status: 'verified', default_locale: 'es'
    )

    expect(described_class.headers_for(organization:)).to eq({})
  end

  it 'falls back to the verified global sender when a tenant is unverified' do
    EmailSenderSetting.create!(
      organization:, from_address: 'local@delta.test',
      domain: 'delta.test', domain_status: 'unverified', default_locale: 'es'
    )
    EmailSenderSetting.create!(
      organization: nil, from_address: 'global@delta.test',
      domain: 'delta.test', domain_status: 'verified', default_locale: 'es'
    )

    expect(described_class.headers_for(organization:)[:from]).to include('global@delta.test')
  end
end
