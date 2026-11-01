# frozen_string_literal: true

RSpec.describe OrganizationSetting, type: :model do
  subject { build(:organization_setting) }

  describe 'validations' do
    it { is_expected.to belong_to(:base_currency).class_name('Currency') }

    it 'rejects an inactive base currency' do
      subject.base_currency.active = false
      expect(subject).not_to be_valid
      expect(subject.errors[:base_currency]).to be_present
    end
    it { is_expected.to validate_presence_of(:timezone) }

    it do
      expect(subject).to validate_inclusion_of(:timezone)
        .in_array(%w[UTC America/Mexico_City America/Monterrey America/Tijuana])
    end

    it { is_expected.to validate_presence_of(:payment_method) }
    it 'exposes the supported payment methods' do
      expect(described_class.payment_methods.keys).to contain_exactly('cash', 'card', 'qr')
    end
  end
end
