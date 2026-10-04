# frozen_string_literal: true

RSpec.describe OrganizationSetting, type: :model do
  subject(:settings) { build(:organization_setting) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:timezone) }
    it { is_expected.to validate_presence_of(:payment_method) }
    it { is_expected.to validate_inclusion_of(:currency).in_array(%w[MXN USD JPY KRW]) }
    it { is_expected.to validate_inclusion_of(:timezone).in_array(OrganizationSetting::ONBOARDING_TIMEZONES) }
    it { is_expected.to validate_inclusion_of(:payment_method).in_array(%w[cash card qr]) }
    it { is_expected.to allow_value('MXN').for(:currency) }
    it { is_expected.not_to allow_value('mxn').for(:currency) }
  end

  it 'soft deletes and restores' do
    settings = create(:organization_setting)
    settings.destroy!

    expect(OrganizationSetting.find_by(id: settings.id)).to be_nil
    expect(OrganizationSetting.with_deleted).to include(settings)

    settings.restore
    expect(OrganizationSetting.find(settings.id)).to eq(settings)
  end
end
