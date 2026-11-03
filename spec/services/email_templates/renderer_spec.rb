# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Renderer do
  def template(html, subject: '{{recipient_name}}')
    EmailTemplateVersion.new(
      subject:, html_body: html, text_body: '{{recipient_name}}',
      allowed_variables: %w[recipient_name activation_url]
    )
  end

  it 'escapes user values and removes scripts and event handlers' do
    content = '<p>{{recipient_name}}</p><script>alert(1)</script>'
    _subject, html, _plain = described_class.new(
      source: template(content), values: { recipient_name: '<img src=x onerror=alert(1)>' }
    ).render

    expect(html).not_to include('<script>')
    expect(html).not_to include('onerror=')
    expect(html).to include('&lt;img')
  end

  it 'rejects a dangerous activation URL' do
    value = { recipient_name: 'Sample', activation_url: 'javascript:alert(1)' }
    expect do
      described_class.new(
        source: template('<a href="{{activation_url}}">Activate</a>'), values: value
      ).render
    end.to raise_error(ArgumentError, /Unsafe email URL/)
  end

  it 'rejects unknown and missing variables' do
    expect do
      described_class.new(
        source: template('<p>{{secret_key}}</p>'), values: { recipient_name: 'Name' }
      ).render
    end.to raise_error(ArgumentError, /Unapproved/)
  end
end
