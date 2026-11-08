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
    published.update!(preheader: 'Important message preview')
    published.publish!(actor: nil)
    draft = template.new_draft!(actor: nil)

    expect(draft.version_number).to eq(published.version_number + 1)
    expect(draft.status).to eq('draft')
    expect(draft.subject).to eq(published.subject)
    expect(draft.preheader).to eq(published.preheader)
  end

  it 'rejects content that exceeds model limits even without HTML5 validation' do
    version = template.new_draft!(actor: nil)
    expect(version.update(subject: 'x' * 251)).to be(false)
    expect(version.errors[:subject]).to be_present
    expect(version.update(preheader: 'x' * 251)).to be(false)
    expect(version.errors[:preheader]).to be_present
  end

  it 'normalizes editor variable lists' do
    version = template.new_draft!(actor: nil)
    version.allowed_variables_csv = ' recipient_name, ,recipient_name, organization_name '
    expect(version.allowed_variables).to eq(%w[recipient_name organization_name])
    expect(version.allowed_variables_csv).to eq('recipient_name, organization_name')
  end

  it 'rejects malformed or unknown allowed variables' do
    version = template.new_draft!(actor: nil)
    expect(version.update(allowed_variables: 'recipient_name')).to be(false)
    expect(version.update(allowed_variables: ['unknown_variable'])).to be(false)
  end

  it 'validates undeclared placeholders on the draft model before saving' do
    version = template.new_draft!(actor: nil)
    expect(version.update(subject: 'Hello {{recipient_name}}', allowed_variables: [])).to be(false)
    expect(version.errors[:allowed_variables]).to be_present
    expect(version.reload.subject).to eq('Draft')
    expect(template.reload.published_version).to be_nil
  end

  it 'protects a published version from deletion but permits removing drafts' do
    published = template.new_draft!(actor: nil)
    published.publish!(actor: nil)
    expect(published.destroy).to be_falsey
    expect(template.new_draft!(actor: nil).destroy).to be_truthy
    expect(published.update(updated_at: 1.second.from_now)).to be(true)
  end

  it 'requires security links in both versions of a customized invitation' do
    EmailTemplate.ensure_invitation_template!
    global = EmailTemplate.global.find_by!(key: 'user_invitation', locale: 'es')
    source = global.published_version
    organization = create(:organization)
    local, = EmailTemplates::Personalizer.call(source: global, organization:, actor: nil)
    draft = local.versions.first

    draft.update!(subject: 'Welcome', preheader: '', html_body: '<p>Welcome</p>',
                  text_body: 'Welcome', allowed_variables: [])
    expect { draft.publish!(actor: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(local.reload.published_version).to be_nil
    expect(draft.errors[:html_body]).to be_present
    expect(draft.errors[:text_body]).to be_present
    expect(draft.errors[:allowed_variables]).to be_present

    draft.update!(html_body: '<a href="{{activation_url}}">Join</a>',
                  text_body: '{{activation_url}}', allowed_variables: ['activation_url'])
    draft.publish!(actor: nil)
    expect(local.reload.published_version).to eq(draft)
    expect(global.reload.published_version).to eq(source)
  end

  it 'rejects locally authored security templates without required recovery links' do
    local = EmailTemplate.create!(
      organization: create(:organization), key: 'password_recovery', name: 'Recover access',
      locale: 'ko', category: 'security', status: 'draft', enabled: false,
      subject: 'Restore your password', html_body: '<p>Reset</p>', text_body: 'Reset'
    )
    version = local.new_draft!(actor: nil)

    expect { version.publish!(actor: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(local.reload.published_version).to be_nil
  end
end
