# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branch operational details', type: :model do
  it 'normalizes optional values and enforces unique active codes within an organization' do
    branch = create(:branch, name: 'Central', code: ' central-01 ', contact_email: ' OFFICE@EXAMPLE.COM ')
    expect(branch).to have_attributes(code: 'CENTRAL-01', contact_email: 'office@example.com')
    duplicate = build(:branch, organization: branch.organization, name: 'Different name', code: 'central-01')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:code]).to be_present
    expect(build(:branch, code: 'CENTRAL-01')).to be_valid
    expect do
      Branch.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end.to raise_error(ActiveRecord::RecordNotUnique)
    branch.update!(deleted_at: Time.current)
    expect(duplicate).to be_valid
  end

  it 'accepts missing optional details and rejects invalid identifiers, email and excessive notes' do
    branch = build(:branch, code: ' ', contact_email: ' ', notes: ' ')
    expect(branch).to be_valid
    expect(branch).to have_attributes(code: nil, contact_email: nil, notes: nil)
    branch.assign_attributes(code: 'invalid code', contact_email: 'invalid', notes: 'x' * 2001)
    expect(branch).not_to be_valid
    expect(branch.errors.attribute_names).to include(:code, :contact_email, :notes)
  end
end
