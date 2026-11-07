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
  it 'validates identity field lengths on the server, including non-browser clients' do
    template = described_class.new(key: 'n' * 101, name: 'N' * 151, category: 'C' * 101,
                                   locale: 'es', subject: 'Subject', html_body: '<p>Body</p>',
                                   text_body: 'Body', status: 'draft')

    expect(template).not_to be_valid
    expect(template.errors.attribute_names).to include(:key, :name, :category)
  end
end
