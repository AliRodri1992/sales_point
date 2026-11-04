# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRoleIconsHelper, type: :helper do
  before { helper.extend(DeltaIconsHelper) }

  it 'renders a distinct decorative SVG for each of the eleven standard roles' do
    icons = described_class::ROLE_ICONS.keys.map do |code|
      role = build(:system_role, code:, name: 'Role', description: nil)
      icon = helper.delta_icon(helper.system_role_icon(role))
      svg = Nokogiri::HTML.fragment(icon).at_css('svg')
      expect(svg['aria-hidden']).to eq('true')
      expect(svg.at_css('path, circle, rect')).to be_present
      svg.to_html
    end
    expect(icons.uniq.size).to eq(11)
  end

  it 'uses the meaning of a customized role name rather than its old code' do
    role = build(:system_role, code: 'cashier', name: 'Contabilidad y tesorería')
    expect(helper.system_role_icon(role)).to eq('banknotes')
  end

  it 'recognizes custom role names in Spanish, English and Korean' do
    ['Auditoría interna', 'Internal audit', '감사 담당'].each do |name|
      role = build(:system_role, code: 'custom_audit', name:)
      expect(helper.system_role_icon(role)).to eq('document-magnifying-glass')
    end
  end

  it 'uses the description when a custom name does not describe the job' do
    role = build(:system_role, code: 'night_team', name: 'Equipo nocturno', description: 'Control de inventario')
    expect(helper.system_role_icon(role)).to eq('cube')
  end

  it 'uses a neutral identity badge when the function is unknown' do
    role = build(:system_role, code: 'custom_role', name: 'Equipo A', description: nil)
    expect(helper.system_role_icon(role)).to eq('identification')
  end
end
