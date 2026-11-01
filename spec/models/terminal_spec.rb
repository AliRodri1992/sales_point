# frozen_string_literal: true

RSpec.describe Terminal, type: :model do
  subject { build(:terminal) }

  describe 'associations' do
    it { is_expected.to belong_to(:branch) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(80) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_length_of(:code).is_at_least(2).is_at_most(40) }
    it { is_expected.to allow_value('POS-001').for(:code) }
    it { is_expected.not_to allow_value('pos-001').for(:code) }
    it { is_expected.not_to allow_value('POS 001').for(:code) }
    it { is_expected.to validate_presence_of(:status) }
    it 'exposes the supported statuses' do
      expect(Terminal.statuses.keys).to contain_exactly('active', 'inactive')
    end
  end

  it 'is valid with valid attributes' do
    expect(subject).to be_valid
  end

  it 'rejects duplicate codes within a branch' do
    existing = create(:terminal, branch: subject.branch, code: 'POS-001')
    duplicate = build(:terminal, branch: existing.branch, code: 'POS-001')

    expect(duplicate).not_to be_valid
  end

  it 'allows duplicate codes in different branches' do
    first = create(:terminal, code: 'POS-001')
    second = build(:terminal, branch: create(:branch), code: 'POS-001')

    expect(second).to be_valid
    expect(first.branch).not_to eq(second.branch)
  end
end
