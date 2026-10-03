# frozen_string_literal: true

RSpec.describe Terminal, type: :model do
  subject(:terminal) { build(:terminal) }

  it { is_expected.to belong_to(:branch) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:code) }

  it 'soft deletes and restores' do
    terminal = create(:terminal)
    terminal.destroy

    expect(Terminal.find_by(id: terminal.id)).to be_nil
    expect(Terminal.with_deleted).to include(terminal)

    terminal.restore
    expect(Terminal.find(terminal.id)).to eq(terminal)
  end
end