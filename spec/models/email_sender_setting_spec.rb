# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailSenderSetting, type: :model do
  it 'derives a new sender domain without treating it as verified' do
    sender = described_class.create!(display_name: 'Shop', from_address: 'hello@first.test')
    expect(sender.domain).to eq('first.test')
    expect(sender.domain_status).to eq('unverified')
  end

  it 'invalidates domain verification after moving to another sender domain' do
    sender = described_class.create!(
      display_name: 'Shop', from_address: 'hello@first.test',
      domain: 'first.test', domain_status: 'verified'
    )
    sender.update!(from_address: 'hello@second.test')
    expect(sender).to have_attributes(domain: 'second.test', domain_status: 'unverified')
  end

  it 'normalizes optional addresses before validation' do
    sender = described_class.new(
      display_name: 'Local brand', default_locale: 'es',
      from_address: ' NOTICE@Example.COM ', reply_to: ' HELP@Example.COM '
    )

    expect(sender).to be_valid
    expect(sender.from_address).to eq('notice@example.com')
    expect(sender.reply_to).to eq('help@example.com')
  end

  it 'rejects a missing sender address on the model' do
    sender = described_class.new(display_name: 'Shop', default_locale: 'es', from_address: ' ')
    expect(sender).not_to be_valid
    expect(sender.errors[:from_address]).to be_present
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

  it 'requires a sender address without falsely marking it verified' do
    sender = described_class.new(display_name: 'Tenant', default_locale: 'es', domain_status: 'unverified')
    expect(sender).not_to be_valid
    expect(sender.errors[:from_address]).to be_present

    sender.from_address = 'alerts@example.org'
    expect(sender.save).to be(true)
    expect(EmailTemplates::Sender.verified?(sender)).to be_falsey
  end
end
