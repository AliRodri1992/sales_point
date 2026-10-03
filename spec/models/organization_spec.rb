# frozen_string_literal: true

RSpec.describe Organization, type: :model do
  subject(:organization) { build(:organization) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:tax_id) }
  it { is_expected.to validate_presence_of(:business_sector) }

  it 'defines the supported statuses' do
    expect(described_class.statuses).to include(
      'active' => 'active',
      'inactive' => 'inactive',
      'suspended' => 'suspended'
    )
  end

  it 'soft deletes and restores' do
    organization = create(:organization)
    organization.destroy!

    expect(Organization.find_by(id: organization.id)).to be_nil
    expect(Organization.with_deleted).to include(organization)

    organization.restore
    expect(Organization.find(organization.id)).to eq(organization)
  end
end
