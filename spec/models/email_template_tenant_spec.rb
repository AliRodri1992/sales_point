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
end
