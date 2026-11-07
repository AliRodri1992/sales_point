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
end
