# frozen_string_literal: true

RSpec.describe OrganizationSetting, type: :model do
  subject { build(:organization_setting) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_inclusion_of(:currency).in_array(%w[MXN USD JPY KRW]) }
    it { is_expected.to validate_presence_of(:timezone) }
    it { is_expected.to validate_inclusion_of(:timezone).in_array(%w[UTC America/Mexico_City America/Monterrey America/Tijuana]) }
    it { is_expected.to validate_presence_of(:payment_method) }
    it 'exposes the supported payment methods' do
      expect(described_class.payment_methods.keys).to contain_exactly('cash', 'card', 'qr')
    end
  end
end
