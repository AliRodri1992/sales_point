# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailSenderSetting, type: :model do
  it 'normalizes optional addresses before validation' do
    sender = described_class.new(
      display_name: 'Local brand', default_locale: 'es',
      from_address: ' NOTICE@Example.COM ', reply_to: ' HELP@Example.COM '
    )

    expect(sender).to be_valid
    expect(sender.from_address).to eq('notice@example.com')
    expect(sender.reply_to).to eq('help@example.com')
  end

  it 'rejects invalid addresses, excessively long names and unsupported locales' do
    sender = described_class.new(
      display_name: 'x' * 151, from_address: 'invalid-address',
      reply_to: 'invalid-reply', default_locale: 'fr'
    )

    expect(sender).not_to be_valid
    %i[display_name from_address reply_to default_locale].each do |attribute|
      expect(sender.errors[attribute]).to be_present
    end
  end

  it 'allows an unverified sender to be saved without falsely becoming deliverable' do
    sender = described_class.create!(display_name: 'Tenant', default_locale: 'es', domain_status: 'unverified')

    expect(sender.from_address).to be_nil
    expect(EmailTemplates::Sender.verified?(sender)).to be_falsey
  end
end
