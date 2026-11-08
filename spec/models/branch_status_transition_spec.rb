# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BranchStatusTransition, type: :model do
  it 'prevents modifications to lifecycle audit records' do
    branch = create(:branch)
    entry = branch.branch_status_transitions.create!(
      from_status: 'active', to_status: 'suspended', reason: 'Maintenance',
      changed_by: create(:user)
    )

    expect(entry.update(reason: 'Altered')).to be(false)
    expect(entry.destroy).to be(false)
    expect(entry.reload.reason).to eq('Maintenance')
  end

  it 'requires a reason when an actor is specified' do
    branch = create(:branch)
    entry = branch.branch_status_transitions.build(
      from_status: 'active', to_status: 'suspended', changed_by: create(:user)
    )
    expect(entry).not_to be_valid
    expect(entry.errors[:reason]).to be_present
  end
end
