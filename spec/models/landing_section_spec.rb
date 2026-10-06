require 'rails_helper'

RSpec.describe LandingSection, type: :model do
  subject(:section) { build(:landing_section) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key) }
    it { is_expected.to validate_inclusion_of(:key).in_array(described_class::KEYS) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_uniqueness_of(:position) }
  end

  describe '.ordered' do
    it 'returns sections by position' do
      later = create(:landing_section, position: 2)
      first = create(:landing_section, position: 1)

      expect(described_class.ordered).to eq([first, later])
    end
  end

  describe '.enabled' do
    it 'returns only visible sections' do
      visible = create(:landing_section, enabled: true)
      create(:landing_section, enabled: false, key: 'benefits', position: 2)

      expect(described_class.enabled).to contain_exactly(visible)
    end
  end
end
