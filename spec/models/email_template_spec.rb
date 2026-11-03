# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplate, type: :model do
  it 'escapes untrusted placeholder values in HTML' do
    template = described_class.new(key: 'test', locale: 'es', subject: '{{name}}',
                                   html_body: '<p>{{name}}</p>', text_body: '{{name}}')
    subject, html, plain = template.render_with(name: '<script>alert(1)</script>')
    expect(subject).to include('<script>')
    expect(html).to include('&lt;script&gt;')
    expect(html).not_to include('<script>')
    expect(plain).to include('<script>')
  end
end
