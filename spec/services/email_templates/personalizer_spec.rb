# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::Personalizer do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:source) do
    global = EmailTemplate.create!(
      key: 'copy_service_test', locale: 'es', name: 'System notice',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Hello {{recipient_name}}',
      html_body: '<p>Hello {{recipient_name}}</p>', text_body: 'Hello {{recipient_name}}'
    )
    global.new_draft!(actor: nil).publish!(actor: nil)
    global
  end

  it 'creates one unpublished tenant draft and reuses it without duplicate audits' do
    template, created = described_class.call(source:, organization:, actor: nil)
    expect(created).to be(true)
    expect(template).to have_attributes(
      organization:, source_template: source, status: 'draft', enabled: false
    )
    expect(template.versions.count).to eq(1)
    expect(template.versions.first.html_body).to eq(source.published_version.html_body)

    existing, second_created = described_class.call(source:, organization:, actor: nil)
    expect(second_created).to be(false)
    expect(existing.id).to eq(template.id)
    expect(template.audits.where(action: 'personalized').count).to eq(1)
    expect(source.reload).to have_attributes(status: 'published', enabled: true)
  end

  it 'isolates customizations by organization' do
    first, = described_class.call(source:, organization:, actor: nil)
    second, = described_class.call(source:, organization: other_organization, actor: nil)

    expect(first.id).not_to eq(second.id)
    expect(first.organization_id).to eq(organization.id)
    expect(second.organization_id).to eq(other_organization.id)
  end

  it 'rejects unpublished sources and missing organizations' do
    draft = EmailTemplate.create!(
      key: 'invalid_copy', locale: 'en', name: 'Unpublished',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Draft', html_body: '<p>Draft</p>', text_body: 'Draft'
    )
    expect { described_class.call(source: draft, organization:, actor: nil) }.to raise_error(ArgumentError)
    expect { described_class.call(source:, organization: nil, actor: nil) }.to raise_error(ArgumentError)
  end
  it 'reuses a manually authored organization template without overriding its content' do
    global = source
    existing = EmailTemplate.create!(
      organization:, key: global.key, locale: global.locale, name: 'Local original',
      category: 'transactional', status: 'draft', enabled: false,
      subject: 'Original', html_body: '<p>Custom</p>', text_body: 'Custom'
    )

    returned, created = described_class.call(source: global, organization:, actor: nil)

    expect(created).to be(false)
    expect(returned.id).to eq(existing.id)
    expect(returned.reload).to have_attributes(name: 'Local original', source_template_id: nil)
    expect(returned.audits).to be_empty
  end

end
