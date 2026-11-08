# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email template tenant resolution', type: :model do
  let(:first_organization) { create(:organization) }
  let(:second_organization) { create(:organization) }

  def template_for(organization, locale, subject)
    EmailTemplate.create!(
      organization:, key: 'welcome_letter', name: 'Welcome letter',
      locale:, category: 'transactional', status: 'published',
      subject:, html_body: '<p>Welcome</p>', text_body: 'Welcome'
    )
  end

  it 'prefers an organization-specific locale over the global default' do
    global = template_for(nil, 'es', 'Global ES')
    local = template_for(first_organization, 'es', 'Local ES')

    expect(EmailTemplate.resolve(key: 'welcome_letter', locale: :es, organization: first_organization)).to eq(local)
    expect(EmailTemplate.resolve(key: 'welcome_letter', locale: :es, organization: second_organization)).to eq(global)
  end

  it 'falls back to global Spanish when requested locale is unavailable' do
    global = template_for(nil, 'es', 'Global ES')
    expect(EmailTemplate.resolve(key: 'welcome_letter', locale: :ko, organization: first_organization)).to eq(global)
  end

  it 'disallows duplicate global templates but allows tenant overrides' do
    template_for(nil, 'es', 'Original')
    duplicate = EmailTemplate.new(
      key: 'welcome_letter', locale: 'es', name: 'Duplicate', category: 'transactional',
      subject: 'Copy', html_body: '<p>Copy</p>', text_body: 'Copy'
    )
    expect(duplicate).not_to be_valid
    expect(template_for(first_organization, 'es', 'Override')).to be_persisted
  end

  it 'falls back to Spanish for unsupported language codes' do
    global = template_for(nil, 'es', 'Spanish fallback')
    expect(EmailTemplate.resolve(key: global.key, locale: 'unsupported')).to eq(global)
    expect(EmailTemplate.visible_to(nil)).to contain_exactly(global)
    expect(EmailTemplate.visible_to(first_organization)).to include(global)
  end

  it 'does not allow attaching a published snapshot from another template' do
    first = template_for(first_organization, 'es', 'First')
    second = template_for(second_organization, 'es', 'Second')
    version = first.new_draft!(actor: nil)
    version.publish!(actor: nil)
    expect(second.update(published_version: version)).to be(false)
    expect(second.errors[:published_version]).to be_present
  end

  it 'protects the key, locale and organization of a published identity' do
    template = template_for(first_organization, 'es', 'Original')
    template.new_draft!(actor: nil).publish!(actor: nil)
    [{ key: 'renamed' }, { locale: 'en' }, { organization: second_organization }].each do |attributes|
      expect(template.update(attributes)).to be(false)
      expect(template.errors[:base]).to be_present
      template.reload
    end
  end
  it 'does not permit linking a custom template to a different global key or language' do
    global = template_for(nil, 'es', 'Original')
    local = template_for(first_organization, 'es', 'Custom')
    expect(local.update(source_template: global)).to be(true)

    local.key = 'different_key'
    expect(local).not_to be_valid
    local.reload
    expect(local.update(organization: second_organization)).to be(false) if local.published_version
  end

end
