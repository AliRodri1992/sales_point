# frozen_string_literal: true

RSpec.describe Terminal, type: :model do
  subject(:terminal) { build(:terminal) }

  it { is_expected.to belong_to(:branch) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:code) }

  describe 'validations' do
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(80) }
    it { is_expected.to validate_length_of(:code).is_at_least(2).is_at_most(40) }
    it { is_expected.to allow_value('POS-001').for(:code) }
    it { is_expected.not_to allow_value('pos 001').for(:code) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active inactive]) }

    it 'requires unique terminal codes within a branch' do
      branch = create(:branch)
      create(:terminal, branch:, code: 'POS-001')

      terminal = build(:terminal, branch:, code: 'POS-001')

      expect(terminal).not_to be_valid
      expect(terminal.errors[:code]).to include('has already been taken')
    end
  end

  it 'soft deletes and restores' do
    terminal = create(:terminal)
    terminal.destroy!

    expect(Terminal.find_by(id: terminal.id)).to be_nil
    expect(Terminal.with_deleted).to include(terminal)

    terminal.restore
    expect(Terminal.find(terminal.id)).to eq(terminal)
  end
end
