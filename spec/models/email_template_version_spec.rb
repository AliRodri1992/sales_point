# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplateVersion, type: :model do
  let(:template) do
    EmailTemplate.create!(
      key: 'billing_notice', name: 'Billing notice', category: 'billing',
      locale: 'es', subject: 'Draft', html_body: '<p>Hello</p>',
      text_body: 'Hello', status: 'draft', enabled: false
    )
  end

  it 'publishes a draft, retaining the immutable published snapshot' do
    version = template.new_draft!(actor: nil)
    version.publish!(actor: nil)

    expect(template.reload.published_version).to eq(version)
    expect(template.status).to eq('published')
    expect(version.reload.published_at).to be_present
    expect(version.update(subject: 'Tampered')).to be(false)
    expect(version.errors[:base]).to be_present
  end

  it 'restores a previous published version as a new draft' do
    published = template.new_draft!(actor: nil)
    published.publish!(actor: nil)
    draft = template.new_draft!(actor: nil)

    expect(draft.version_number).to eq(published.version_number + 1)
    expect(draft.status).to eq('draft')
    expect(draft.subject).to eq(published.subject)
  end
end
