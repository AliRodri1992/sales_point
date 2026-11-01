# frozen_string_literal: true

RSpec.describe Onboarding::ProgressCalculator, type: :service do
  it 'reports progressive completion without blocking access' do
    organization = create(:organization, :with_settings)
    create(:employee, organization:)

    progress = described_class.call(organization)

    expect(progress[:sections]).to include(
      include(key: :company, status: 'completed'),
      include(key: :fiscal, status: 'completed'),
      include(key: :branches, status: 'not_started'),
      include(key: :terminals, status: 'not_started'),
      include(key: :payments, status: 'completed'),
      include(key: :migration, status: 'not_applicable'),
      include(key: :team, status: 'completed')
    )
    expect(progress[:sections].size).to eq(7)
    expect(progress[:percentage]).to eq(67)
  end

  it 'handles an organization without settings, branches, or migration records' do
    organization = create(:organization)

    progress = described_class.call(organization)
    sections = progress[:sections].index_by { |section| section[:key] }

    expect(sections[:company]).to include(percentage: 50, status: 'in_progress')
    expect(sections[:branches]).to include(percentage: 0, status: 'not_started')
    expect(sections[:payments]).to include(percentage: 0, status: 'not_started')
    expect(sections[:migration]).to include(percentage: 0, status: 'not_applicable')
    expect(progress[:percentage]).to be_between(0, 100)
  end

  it 'reports partial configuration as in progress' do
    organization = create(:organization)
    create(:branch, organization:, without_address: true)

    progress = described_class.call(organization)

    expect(progress[:sections]).to include(
      include(key: :company, percentage: 50, status: 'in_progress'),
      include(key: :fiscal, status: 'completed'),
      include(key: :branches, percentage: 50, status: 'in_progress'),
      include(key: :terminals, status: 'not_started'),
      include(key: :payments, status: 'not_started'),
      include(key: :migration, status: 'not_applicable'),
      include(key: :team, status: 'not_started')
    )
  end

  it 'reports a missing branch address as incomplete' do
    organization = create(:organization)
    create(:branch, organization:, without_address: true)

    progress = described_class.call(organization)
    section = progress[:sections].find { |item| item[:key] == :branches }

    expect(section[:percentage]).to eq(50)
    expect(section[:status]).to eq('in_progress')
  end

  it 'reports fully configured operational sections as completed' do
    organization = create(:organization, :with_settings)
    create(:branch, organization:)
    create(:terminal, branch: organization.branches.first)
    create(:employee, organization:)
    organization.organization_settings.first.update!(payment_method: :card)

    progress = described_class.call(organization)

    expect(progress[:sections]).to all(include(:key, :percentage, :status))
    expect(progress[:sections]).to include(include(key: :migration, status: 'not_applicable', percentage: 0))
    expect(progress[:sections].reject do |section|
      section[:status] == 'not_applicable'
    end).to all(include(status: 'completed'))
    expect(progress[:percentage]).to eq(100)
  end

  it 'treats an inactive branch as incomplete until an active branch exists' do
    organization = create(:organization)
    create(:branch, organization:, status: false)

    progress = described_class.call(organization)
    branch_section = progress[:sections].find { |section| section[:key] == :branches }
    terminal_section = progress[:sections].find { |section| section[:key] == :terminals }

    expect(branch_section).to include(percentage: 0, status: 'not_started')
    expect(terminal_section).to include(percentage: 0, status: 'not_started')
  end

  it 'calculates migration progress when migration data is present' do
    organization = create(:organization)
    migration = create(:organization_migration, organization:, volume: :small, priority: :catalog)

    progress = described_class.call(organization)
    migration_section = progress[:sections].find { |section| section[:key] == :migration }

    expect(migration_section).to include(percentage: 100, status: 'completed')
    expect(migration).to be_persisted
  end
end
