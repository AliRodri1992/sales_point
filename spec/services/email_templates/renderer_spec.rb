# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Renderer do
  def template(html, subject: '{{recipient_name}}')
    EmailTemplateVersion.new(
      subject:, html_body: html, text_body: '{{recipient_name}}',
      allowed_variables: %w[recipient_name activation_url]
    )
  end

  it 'renders legacy nonversioned content without a preheader attribute' do
    draft = EmailTemplate.new(
      subject: 'Subject', html_body: '<p>Hello</p>', text_body: 'Hello'
    )
    expect(described_class.new(source: draft, values: {}).render.first).to eq('Subject')
  end

  it 'escapes user values and removes scripts and event handlers' do
    content = '<p onclick="alert(1)">{{recipient_name}}</p><script>alert(1)</script>'
    _subject, html, _plain = described_class.new(
      source: template(content), values: { recipient_name: '<img src=x onerror=alert(1)>' }
    ).render

    document = Nokogiri::HTML.fragment(html)
    expect(document.css('script, [onerror], [onclick]')).to be_empty
    expect(html).to include('&lt;img')
  end

  it 'enlarges older standard platform logos when rendering published email content' do
    legacy_markup = '<img src="{{platform_logo}}" width="244" alt="Delta POS" ' \
                    'style="display:block;width:244px;max-width:100%;height:auto">'
    source = template(legacy_markup)
    source.allowed_variables = %w[recipient_name platform_logo]

    _subject, html, _plain = described_class.new(
      source:, values: { recipient_name: 'Sample', platform_logo: 'https://example.org/logo.png' }
    ).render

    logo = Nokogiri::HTML.fragment(html).at_css('img')
    expect(logo['width']).to eq('320')
    expect(logo['style']).to include('width:320px')
  end

  it 'preserves custom platform logo sizes and other image dimensions' do
    markup = '<img src="{{platform_logo}}" width="380" style="width:380px">' \
             '<img src="https://example.org/other.png" width="244" style="width:244px">'
    source = template(markup)
    source.allowed_variables = %w[recipient_name platform_logo]

    _subject, html, _plain = described_class.new(
      source:, values: { recipient_name: 'Sample', platform_logo: 'https://example.org/logo.png' }
    ).render

    images = Nokogiri::HTML.fragment(html).css('img')
    expect(images.pluck('width')).to eq(%w[380 244])
  end

  it 'rejects a dangerous activation URL' do
    value = { recipient_name: 'Sample', activation_url: 'javascript:alert(1)' }
    expect do
      described_class.new(
        source: template('<a href="{{activation_url}}">Activate</a>'), values: value
      ).render
    end.to raise_error(ArgumentError, /Unsafe email URL/)
  end

  it 'rejects URL credentials and links without a valid host' do
    ['https://user:password@example.org/private', 'https:///missing-host'].each do |url|
      expect do
        described_class.new(
          source: template('<a href="{{activation_url}}">Activate</a>'),
          values: { recipient_name: 'Sample', activation_url: url }
        ).render
      end.to raise_error(ArgumentError, /Unsafe email URL|Invalid email URL/)
    end
  end

  it 'rejects example-domain links in production but accepts real configured hosts' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    source = template('<a href="{{activation_url}}">Activate</a>')
    values = { recipient_name: 'Sample', activation_url: 'https://example.org/activate' }

    expect do
      described_class.new(source:, values:).render
    end.to raise_error(ArgumentError, /Unconfigured email URL/)

    values[:activation_url] = 'https://notifications.delta-pos.mx/activate'
    expect { described_class.new(source:, values:).render }.not_to raise_error
  end

  it 'permits example links only in sandboxed previews, never in production delivery' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    source = template('<a href="{{activation_url}}">Activate</a>')
    values = { recipient_name: 'Sample', activation_url: 'https://example.org/demo' }

    expect { described_class.new(source:, values:).render }.to raise_error(ArgumentError, /Unconfigured/)
    _subject, html, _plain = described_class.new(source:, values:, preview: true).render
    expect(html).to include('https://example.org/demo')
  end

  it 'rejects placeholder support email addresses in production delivery' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    source = template('<p>{{support_email}}</p>')
    source.allowed_variables = %w[recipient_name support_email]
    values = { recipient_name: 'Sample', support_email: 'support@example.org' }

    expect { described_class.new(source:, values:).render }.to raise_error(ArgumentError, /Unconfigured support email/)
    expect { described_class.new(source:, values:, preview: true).render }.not_to raise_error
    values[:support_email] = 'support@delta.test'
    expect { described_class.new(source:, values:).render }.not_to raise_error
  end

  it 'rejects unknown and missing variables' do
    expect do
      described_class.new(
        source: template('<p>{{secret_key}}</p>'), values: { recipient_name: 'Name' }
      ).render
    end.to raise_error(ArgumentError, /Unapproved/)
  end

  it 'rejects malformed placeholders even for legacy sources without model validation' do
    ['{{ recipient_name }}', '{{recipient-name}}', '{{recipient_name', 'recipient_name}}'].each do |value|
      source = template("<p>#{value}</p>")
      expect do
        described_class.new(source:, values: { recipient_name: 'Test' }).render
      end.to raise_error(ArgumentError, /Malformed email variable/)
    end
  end

  it 'refuses to render sensitive links in headers from legacy published content' do
    header_fields = %i[subject preheader]
    %w[activation_url recovery_url].each do |name|
      header_fields.each do |field|
        source = template('<a href="{{activation_url}}">Activate</a>')
        source.allowed_variables = %w[recipient_name activation_url recovery_url]
        source.public_send("#{field}=", "Secret {{#{name}}}")

        expect do
          described_class.new(source:, values: { recipient_name: 'Test', activation_url: 'https://delta.test/start',
                                                 recovery_url: 'https://delta.test/reset' }).render
        end.to raise_error(ArgumentError, /Sensitive email URL in header/)
      end
    end
  end

  it 'injects an escaped, variable-aware preheader into sent HTML' do
    source = template('<p>Body</p>')
    source.preheader = 'Hola {{recipient_name}} & gracias'
    _subject, html, _plain = described_class.new(
      source:, values: { recipient_name: '<Pat>' }
    ).render

    document = Nokogiri::HTML.fragment(html)
    expect(document.at_css('div[style*="display:none"]')).to be_present
    expect(html).to include('Hola &lt;Pat&gt; &amp; gracias')
    expect(html).not_to include('<Pat>')
  end
end
