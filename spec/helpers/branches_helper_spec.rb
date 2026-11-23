# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BranchesHelper, type: :helper do
  it 'shows a pending location when the address has no usable locality information' do
    address = double('address', city: nil, state: nil, country: nil)
    branch = double('branch', address:)

    expect(helper.branch_location(branch)).to eq(I18n.t('admin.branch_workspace.location_pending'))
  end

  it 'shows a pending location when no address has been registered' do
    branch = double('branch', address: nil)

    expect(helper.branch_location(branch)).to eq(I18n.t('admin.branch_workspace.location_pending'))
  end

  it 'shows the prerequisites and blockers for the selected transition' do
    branch = create(:branch)
    create(:terminal, branch:)
    allow(helper).to receive(:current_user).and_return(nil)

    expect(helper.branch_transition_blockers(branch, :active)).to contain_exactly(:currency, :team)
    expect(helper.branch_transition_blockers(branch, :suspended)).to contain_exactly(:active_terminals)
    expect(helper.branch_transition_blockers(branch, :closed)).to contain_exactly(:active_terminals)
    expect(helper.branch_transition_blockers(branch, :preparing)).to be_empty
  end

  it 'links each procurement blocker to the corresponding queue' do
    branch = build_stubbed(:branch)
    expect(helper.branch_blocker_path(branch, :pending_requests)).to eq(helper.admin_purchase_requests_path)
    expect(helper.branch_blocker_path(branch, :pending_orders)).to eq(helper.admin_purchase_orders_path)
    expect(helper.branch_blocker_path(branch, :pending_returns)).to eq(helper.admin_purchase_returns_path)
  end

  it 'retains the selected inactive country in the address form' do
    country = create(:country, active: false)
    options = helper.branch_country_options(Address.new(country:))
    expect(options.map(&:second)).to include(country.id)
    expect(options.find { |option| option.second == country.id }.first).to eq(country.localized_name)
  end

  it 'omits the country name when a directory filter references an unavailable country' do
    expect(helper.branch_filter_badge_value('country_id', '999', [])).to be_nil
  end
end
