# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Branding do
  let(:organization) { create(:organization) }

  it 'uses platform defaults when no branding is configured' do
    values = described_class.values
    expect(values).to include(platform_name: 'Delta POS', organization_name: 'Delta POS')
    expect(values[:support_url]).to start_with('https://')
    expect(values[:logo_url]).to include('delta-pos-logo')
  end

  it 'combines local identity with global contact fallbacks' do
    EmailBrandingSetting.create!(
      display_name: 'Platform', support_email: 'help@platform.example', support_url: 'https://platform.example/help'
    )
    local = EmailBrandingSetting.create!(organization:, display_name: 'Tenant', privacy_url: 'https://tenant.example/privacy')
    local.logo.attach(io: StringIO.new('image data'), filename: 'logo.png', content_type: 'image/png')
    expect(local).to be_valid
    values = described_class.values(organization:)
    expect(values).to include(
      platform_name: 'Platform', organization_name: 'Tenant', support_email: 'help@platform.example',
      support_url: 'https://platform.example/help', privacy_url: 'https://tenant.example/privacy'
    )
    expect(values[:organization_logo]).to include('/rails/active_storage/blobs/')
  end

  it 'rejects executable or oversized logos' do
    setting = EmailBrandingSetting.new(display_name: 'Tenant')
    setting.logo.attach(io: StringIO.new('<svg/>'), filename: 'logo.svg', content_type: 'image/svg+xml')
    expect(setting).not_to be_valid
    setting.logo.attach(io: StringIO.new('x' * (2.megabytes + 1)), filename: 'large.png', content_type: 'image/png')
    expect(setting).not_to be_valid
    expect(setting.errors[:logo]).to be_present
  end
end
