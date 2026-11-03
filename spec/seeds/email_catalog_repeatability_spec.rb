# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email catalog seed repeatability', type: :model do
  it 'does not duplicate templates or versions or overwrite a published message' do
    seed = Rails.root.join('db/seeds/email_catalog.rb')
    load seed
    original = EmailTemplate.global.find_by!(key: 'user_welcome', locale: 'es')
    original.update!(subject: 'Approved custom welcome')
    template_ids = EmailTemplate.global.order(:id).pluck(:id)
    version_ids = EmailTemplateVersion.order(:id).pluck(:id)

    load seed

    expect(EmailTemplate.global.order(:id).pluck(:id)).to eq(template_ids)
    expect(EmailTemplateVersion.order(:id).pluck(:id)).to eq(version_ids)
    expect(original.reload.subject).to eq('Approved custom welcome')
  end
end
