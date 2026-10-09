# frozen_string_literal: true

RSpec.describe Onboarding::TerminalsUpdater, type: :service do
  it 'returns false when no terminals are available' do
    organization = create(:organization)

    expect(described_class.call(organization, {}, terminals: [])).to be(false)
  end

  it 'uses supplied terminals and preserves the number of records' do
    organization = create(:organization)
    branch = create(:branch, organization:)
    terminals = [
      create(:terminal, branch:, name: 'Old One'),
      create(:terminal, branch:, name: 'Old Two')
    ]

    result = described_class.call(
      organization,
      { terminal_names: { '0' => 'Caja Principal' } },
      terminals: terminals
    )

    expect(result).to be(true)
    expect(terminals.map { |terminal| terminal.reload.name }).to eq(
      ['Caja Principal', 'POS Terminal 2']
    )
    expect(branch.terminals.count).to eq(2)
  end

  it 'uses the active branch before a non-active branch' do
    organization = create(:organization)
    create(:branch, organization:, name: 'Sucursal Norte', status: false)
    active_branch = create(:branch, organization:, name: 'Sucursal Centro', status: true)
    terminal = create(:terminal, branch: active_branch)

    expect(described_class.call(organization, {}, terminals: nil)).to be(true)
    expect(terminal.reload.name).to eq('POS Terminal 1')
  end
end
