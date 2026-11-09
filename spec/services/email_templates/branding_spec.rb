# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Branding do
  let(:organization) { create(:organization) }

  it 'supports real configured contact fallbacks without changing tenant overrides' do
    allow(ENV).to receive(:fetch).with('DELTA_POS_SUPPORT_EMAIL', 'support@example.org').and_return('help@delta.test')
    allow(ENV).to receive(:fetch).with('DELTA_POS_SUPPORT_URL', 'https://example.org/support')
                                 .and_return('https://delta.test/support')
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_URL', 'https://example.org/privacy')
                                 .and_return('https://delta.test/privacy')

    values = described_class.values
    expect(values).to include(support_email: 'help@delta.test', support_url: 'https://delta.test/support',
                              privacy_url: 'https://delta.test/privacy')
  end

  it 'rejects example hosts in production rather than sending broken asset links' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DELTA_POS_PUBLIC_HOST').and_return('www.example.org')

    expect { described_class.configured_host }
      .to raise_error(ArgumentError, /DELTA_POS_PUBLIC_HOST/)
  end

  it 'requires a configured production host and accepts a real domain' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:[]).and_call_original
    allow(Rails.application.config.action_mailer).to receive(:default_url_options).and_return({})
    allow(ENV).to receive(:[]).with('DELTA_POS_PUBLIC_HOST').and_return(nil)

    expect { described_class.configured_host }
      .to raise_error(ArgumentError, /DELTA_POS_PUBLIC_HOST/)

    allow(ENV).to receive(:[]).with('DELTA_POS_PUBLIC_HOST').and_return('mail.delta.test')
    expect(described_class.configured_host).to eq('mail.delta.test')
  end

  it 'uses platform defaults when no branding is configured' do
    values = described_class.values
    expect(values).to include(platform_name: 'Delta POS', organization_name: 'Delta POS')
    expect(values[:support_url]).to start_with('https://')
    expect(values[:logo_url]).to include('delta-pos-email-logo')
  end

  it 'uses the official Delta POS SVG on screen and its matching PNG for email clients' do
    values = described_class.values
    expect(described_class::PLATFORM_LOGO_WEB).to eq('delta-pos-email-logo.svg')
    expect(described_class::PLATFORM_LOGO_EMAIL).to eq('delta-pos-email-logo.png')
    expect(values[:platform_logo]).to match(%r{\Ahttps://.+/delta-pos-email-logo[^/]*\.png\z})
    expect(values[:logo_url]).to eq(values[:platform_logo])
    expect(values[:organization_logo]).to eq(values[:platform_logo])
    svg = Rails.root.join('app/assets/images', described_class::PLATFORM_LOGO_WEB)
    png = Rails.root.join('app/assets/images', described_class::PLATFORM_LOGO_EMAIL)
    expect(svg).to exist
    expect(png).to exist
    expect(svg.read).to include('DELTA POS', 'Point of Sale')
    expect(svg.read).not_to include('NEXO')
  end

  it 'requires only the contact variables used by a production email and honors configured overrides' do
    template = EmailTemplate.create!(
      organization:, key: 'help_links', name: 'Help links', category: 'security', locale: 'es',
      status: 'draft', subject: 'Help', html_body: '<p>Help</p>', text_body: 'Help'
    )
    source = template.new_draft!(actor: nil)
    source.update!(
      html_body: '<p>{{support_email}} {{support_url}} {{privacy_url}}</p>',
      text_body: '{{support_email}} {{support_url}} {{privacy_url}}',
      allowed_variables: %w[support_email support_url privacy_url]
    )
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:fetch).and_call_original
    %w[DELTA_POS_SUPPORT_EMAIL DELTA_POS_SUPPORT_URL DELTA_POS_PRIVACY_URL].zip(
      ['support@example.org', 'https://example.org/support', 'https://example.org/privacy']
    ).each do |key, value|
      allow(ENV).to receive(:fetch).with(key, anything).and_return(value)
    end

    missing = EmailTemplates::DeliveryReadiness.missing_contacts(source:, organization:)
    expect(missing).to match_array(%w[support_email support_url privacy_url])

    EmailBrandingSetting.create!(
      display_name: 'Platform', support_email: 'help@delta-pos.mx', support_url: 'https://delta-pos.mx/help'
    )
    EmailBrandingSetting.create!(
      organization:, display_name: 'Shop', privacy_url: 'https://delta-pos.mx/privacy'
    )
    expect(EmailTemplates::DeliveryReadiness.missing_contacts(source:, organization:)).to be_empty

    source.update!(html_body: '<p>Plain message</p>', text_body: 'Plain message', allowed_variables: [])
    expect(EmailTemplates::DeliveryReadiness.missing_contacts(source:, organization:)).to be_empty
  end

  it 'rejects credential-bearing contact URLs even when provided as an environment fallback' do
    source = EmailTemplateVersion.new(subject: 'Privacy', html_body: '{{privacy_url}}', text_body: 'Privacy')
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:fetch).and_call_original
    fallback = 'https://user:password@delta-pos.mx/privacy'
    allow(ENV).to receive(:fetch).with('DELTA_POS_PRIVACY_URL', 'https://example.org/privacy').and_return(fallback)

    expect(EmailTemplates::DeliveryReadiness.missing_contacts(source:, organization: nil))
      .to eq(['privacy_url'])
  end

  it 'uses the local HTTP asset host while editing email previews in development' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
    allow(Rails.application.config.action_mailer).to receive(:asset_host).and_return('http://localhost:3000')

    expect(described_class.platform_logo_url).to start_with('http://localhost:3000/')
    expect(described_class.platform_logo_url).to include('delta-pos-email-logo')
  end

  it 'uses a configured global organization logo when no local logo is present' do
    global = EmailBrandingSetting.create!(display_name: 'Global Store')
    global.logo.attach(io: StringIO.new('image data'), filename: 'logo.png', content_type: 'image/png')

    values = described_class.values(organization:)
    expect(values[:organization_logo]).to include('/rails/active_storage/blobs/')
    expect(values[:platform_logo]).to include('delta-pos-email-logo')
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

  it 'rejects weak white-on-button contrast and invalid support email' do
    setting = EmailBrandingSetting.new(
      display_name: 'Shop', button_color: '#ffffff', support_email: 'invalid'
    )

    expect(setting).not_to be_valid
    expect(setting.errors[:button_color]).to be_present
    expect(setting.errors[:support_email]).to be_present
  end

  it 'keeps valid accessible colors and optional contact details' do
    setting = EmailBrandingSetting.new(
      display_name: 'Shop', button_color: '#047857',
      support_email: 'help@example.org', support_url: 'https://example.org/help'
    )

    expect(setting).to be_valid
  end

  it 'passes tenant color settings and footer through the renderer values' do
    EmailBrandingSetting.create!(
      organization:, display_name: 'Store', primary_color: '#123456',
      secondary_color: '#456789', button_color: '#047857', footer_text: 'Store footer'
    )
    expect(described_class.values(organization:)).to include(
      primary_color: '#123456', secondary_color: '#456789',
      button_color: '#047857', footer_text: 'Store footer'
    )
  end
end
