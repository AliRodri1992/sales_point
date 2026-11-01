# frozen_string_literal: true

RSpec.describe Organization, type: :model do
  subject(:organization) { build(:organization) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:tax_id) }
  it { is_expected.to validate_presence_of(:business_sector) }
  it { is_expected.to validate_presence_of(:onboarding_status) }

  it 'validates the onboarding business sectors' do
    expect(organization).to allow_value(*Organization::ONBOARDING_BUSINESS_SECTORS).for(:business_sector)
    expect(organization).not_to allow_value('other').for(:business_sector)
  end

  it 'validates the Mexican tax identifier format' do
    expect(organization).to allow_value('ABC010203AB1').for(:tax_id)
    expect(organization).to allow_value('ABCD010203AB1').for(:tax_id)
    expect(organization).not_to allow_value('ABC123').for(:tax_id)
    expect(organization).not_to allow_value('ABC010203').for(:tax_id)
  end

  it 'defines the supported statuses' do
    expect(described_class.statuses).to include(
      'active' => 'active',
      'inactive' => 'inactive',
      'suspended' => 'suspended'
    )
  end

  it 'defines the onboarding lifecycle' do
    expect(described_class.onboarding_statuses).to eq(
      'pending' => 'pending',
      'in_progress' => 'in_progress',
      'completed' => 'completed'
    )
  end

  it 'starts with pending onboarding state' do
    expect(organization.onboarding_status).to eq('pending')
    expect(organization.onboarding_current_step).to eq(1)
  end

  it 'resumes an in-progress onboarding without resetting its step' do
    organization = create(:organization, onboarding_status: :in_progress, onboarding_current_step: 3)
    organization.start_onboarding!

    expect(organization.reload.onboarding_status).to eq('in_progress')
    expect(organization.onboarding_current_step).to eq(3)
  end

  it 'starts onboarding without changing a completed organization' do
    organization = create(:organization)
    organization.start_onboarding!

    expect(organization.onboarding_status).to eq('in_progress')

    organization.complete_onboarding!
    organization.start_onboarding!

    expect(organization.onboarding_status).to eq('completed')
    expect(organization.onboarding_completed_at).to be_present
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
