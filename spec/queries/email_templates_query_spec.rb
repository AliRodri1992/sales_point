# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplatesQuery do
  let(:organization) { create(:organization) }
  let!(:global) do
    EmailTemplate.create!(
      key: 'query_global', locale: 'es', name: 'System template',
      category: 'security', status: 'draft', enabled: false,
      subject: 'Notice', html_body: '<p>Notice</p>', text_body: 'Notice'
    )
  end
  let!(:customized) do
    EmailTemplate.create!(
      organization:, source_template: global, key: global.key, locale: global.locale,
      name: 'Customized template', category: 'security', status: 'draft', enabled: false,
      subject: 'Custom', html_body: '<p>Custom</p>', text_body: 'Custom'
    )
  end
  let!(:organization_template) do
    EmailTemplate.create!(
      organization:, key: 'query_own', locale: 'es', name: 'Own template',
      category: 'security', status: 'draft', enabled: false,
      subject: 'Own', html_body: '<p>Own</p>', text_body: 'Own'
    )
  end

  let(:filtered_scope) { EmailTemplate.where(key: %w[query_global query_own]) }

  it 'includes archived entries in filtered status counters' do
    global.update!(status: 'archived')
    counts = described_class.new(
      filtered_scope, { category: 'security', locale: 'es' }, include_archived: true
    ).call.group(:status).count

    expect(counts).to include('archived' => 1, 'draft' => 2)
    expect(described_class.new(filtered_scope, category: 'security').call).not_to include(global)
  end

  it 'filters global, customized and organization-authored templates by origin' do
    expect(described_class.new(filtered_scope, origin: 'system').call).to include(global)
    expect(described_class.new(filtered_scope, origin: 'customized').call).to contain_exactly(customized)
    organization_results = described_class.new(filtered_scope, origin: 'organization').call
    expect(organization_results).to contain_exactly(organization_template)
  end
end
