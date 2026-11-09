# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::InvitationEligibility do
  it 'requires an employee role in the invited organization instead of another company' do
    first = create(:organization)
    second = create(:organization)
    employee = create(:user, user_type: :employee)
    create(:organization_membership, user: employee, organization: first)
    create(:organization_membership, user: employee, organization: second)
    role = create(:system_role, :system, code: 'company_invitation_staff')
    create(:user_role, user: employee, system_role: role, organization: first)

    expect(described_class.roles_ready?(user: employee, organization: first)).to be(true)
    expect(described_class.roles_ready?(user: employee, organization: second)).to be(false)
  end
end
