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

  it 'reports an invalid variables list once even with several unknown entries' do
    version = template.new_draft!(actor: nil)

    expect(version.update(allowed_variables: %w[unknown_one unknown_two unknown_three])).to be(false)
    expect(version.errors[:allowed_variables].size).to eq(1)
  end

  it 'does not stack undeclared-variable errors on top of invalid variable-list errors' do
    version = template.new_draft!(actor: nil)
    version.subject = 'Hello {{recipient_name}}'
    version.allowed_variables = ['unknown_variable']

    expect(version).not_to be_valid
    expect(version.errors[:allowed_variables].size).to eq(1)
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

  it 'rejects malformed or unfinished placeholders directly on their model fields' do
    draft = template.new_draft!(actor: nil)

    {
      subject: 'Hi {{ recipient_name }}',
      preheader: 'Preview {{recipient-name}}',
      html_body: '<p>{{recipient_name</p>',
      text_body: 'Hi recipient_name}}'
    }.each do |field, invalid|
      draft.public_send("#{field}=", invalid)
      expect(draft).not_to be_valid
      expect(draft.errors[field]).to be_present
      draft.reload
    end
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

  it 'rejects security links that disappear or cannot be used after HTML sanitization' do
    secure = EmailTemplate.create!(
      key: 'password_recovery', name: 'Recovery test', category: 'security',
      locale: 'es', subject: 'Recover', html_body: '<p>Reset</p>',
      text_body: 'Reset', status: 'draft', enabled: false
    )
    draft = secure.new_draft!(actor: nil)
    invalid_markup = [
      '<!-- <a href="{{recovery_url}}">Reset</a> -->',
      '<p>{{recovery_url}}</p>',
      '<a href="{{recovery_url}}" style="display:none">Hidden</a>',
      '<div style="visibility:hidden"><a href="{{recovery_url}}">Hidden</a></div>',
      '<a href="{{recovery_url}}"></a>',
      '<a href="javascript:alert(1)">{{recovery_url}}</a>'
    ]
    invalid_markup.each do |markup|
      draft.update!(html_body: markup, text_body: '{{recovery_url}}', allowed_variables: ['recovery_url'])
      expect { draft.publish!(actor: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(draft.errors[:html_body]).to be_present
      expect(draft.reload.status).to eq('draft')
    end

    draft.update!(html_body: '<a href="{{recovery_url}}">Restore access</a>')
    draft.publish!(actor: nil)
    expect(secure.reload.published_version).to eq(draft)
  end

  it 'requires a visible label on sanitized security links in all supported locales' do
    invalid_labels = [
      '<span style="display:none">Reset</span>',
      '<span style="font-size:0px">Reset</span>',
      '<span style="visibility:hidden">Reset</span>',
      '<img src="https://delta.test/icon.png" alt="Reset" style="opacity:0">'
    ]

    %w[es en ko].each do |locale|
      secure = EmailTemplate.create!(
        key: 'password_recovery', name: "Recovery #{locale}", category: 'security',
        locale:, subject: 'Recovery', html_body: '<p>Reset</p>',
        text_body: 'Reset', status: 'draft', enabled: false
      )
      draft = secure.new_draft!(actor: nil)
      invalid_labels.each do |label|
        draft.update!(html_body: %(<a href="{{recovery_url}}">#{label}</a>),
                      text_body: '{{recovery_url}}', allowed_variables: ['recovery_url'])
        expect { draft.publish!(actor: nil) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(draft.errors[:html_body]).to be_present
        expect(draft.reload.status).to eq('draft')
      end

      draft.update!(html_body: '<a href="{{recovery_url}}"><span style="display:none">Hidden</span>Reset access</a>')
      draft.publish!(actor: nil)
      expect(secure.reload.published_version).to eq(draft)
    end
  end

  it 'protects essential security links in global published versions' do
    global = EmailTemplate.create!(
      key: 'password_recovery', name: 'Password recovery', locale: 'en',
      category: 'security', subject: 'Recover', html_body: '<p>Recover</p>',
      text_body: 'Recover', status: 'draft', enabled: false
    )
    draft = global.new_draft!(actor: nil)
    expect { draft.publish!(actor: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(draft.errors[:html_body]).to be_present
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
  it 'rejects manually creating a second editable draft' do
    template.new_draft!(actor: nil)
    duplicate = template.versions.build(version_number: 2, status: 'draft', subject: 'Second',
                                        html_body: '<p>Second</p>', text_body: 'Second')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:status]).to be_present
  end

  it 'reuses an existing draft without creating duplicate versions' do
    first = template.new_draft!(actor: nil)
    first.update!(subject: 'Unsaved editor work')

    second = template.new_draft!(actor: nil)

    expect(second.id).to eq(first.id)
    expect(second.subject).to eq('Unsaved editor work')
    expect(template.versions.where(status: 'draft').count).to eq(1)
  end

  it 'rejects concurrent modifications of the same draft' do
    draft = template.new_draft!(actor: nil)
    stale = described_class.find(draft.id)
    draft.update!(subject: 'First change')

    expect do
      stale.update!(subject: 'Overwritten change')
    end.to raise_error(ActiveRecord::StaleObjectError)
    expect(draft.reload.subject).to eq('First change')
  end

  it 'rejects security URLs in both headers before publishing in every locale' do
    url_variables = %w[activation_url recovery_url]
    header_fields = %i[subject preheader]
    %w[es en ko].each do |locale|
      template.update!(locale:)
      version = template.new_draft!(actor: nil)
      url_variables.each do |url_variable|
        header_fields.each do |header|
          version.public_send("#{header}=", "Token {{#{url_variable}}}")
          version.allowed_variables = [url_variable]
          expect(version).not_to be_valid
          expect(version.errors[header]).to be_present
          version.reload
        end
      end
    end
  end

  it 'prevents stale publication from generating a second version update' do
    version = template.new_draft!(actor: nil)
    stale = described_class.find(version.id)

    version.publish!(actor: nil)

    expect { stale.publish!(actor: nil) }.to raise_error(ActiveRecord::StaleObjectError)
    expect(template.reload.published_version).to eq(version)
    expect(template.versions.where(status: 'published').count).to eq(1)
  end

  it 'rejects unconfigured contact details in production only when a template uses them' do
    organization = create(:organization)
    local = EmailTemplate.create!(
      organization:, key: 'receipt_email', name: 'Receipt', category: 'transactional',
      locale: 'es', subject: 'Receipt', html_body: '<p>Receipt</p>',
      text_body: 'Receipt', status: 'draft', enabled: false
    )
    version = local.new_draft!(actor: nil)
    version.update!(html_body: '<p>{{support_email}}</p><a href="{{support_url}}">Help</a>',
                    text_body: '{{support_email}} {{support_url}}',
                    allowed_variables: %w[support_email support_url])
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

    expect { version.publish!(actor: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(version.errors[:allowed_variables].join).to include('support_email', 'support_url')
    expect(local.reload.published_version).to be_nil

    EmailBrandingSetting.create!(organization:, display_name: 'Shop',
                                 support_email: 'help@delta.test', support_url: 'https://delta.test/support')
    version.publish!(actor: nil)
    expect(local.reload.published_version).to eq(version)
  end

  it 'does not require unused branding contacts to publish in production' do
    version = template.new_draft!(actor: nil)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

    version.publish!(actor: nil)
    expect(template.reload.published_version).to eq(version)
  end

  it 'rejects header line breaks in subjects and preheaders' do
    version = template.new_draft!(actor: nil)

    expect(version.update(subject: "Hello\nUnexpected header")).to be(false)
    expect(version.errors[:subject]).to be_present
    expect(version.update(subject: 'Hello', preheader: "Preview\r\nInjected")).to be(false)
    expect(version.errors[:preheader]).to be_present
  end
end
