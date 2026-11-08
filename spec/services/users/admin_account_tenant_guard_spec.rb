# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::AdminAccountTenantGuard do
  let(:organization) { create(:organization) }
  let(:administrator_role) { create(:system_role, :system, code: 'administrator') }
  let(:super_admin_role) { create(:system_role, :system, code: 'super_admin') }
  let(:target) { create(:user, system_roles: [super_admin_role]) }

  before { create(:organization_membership, user: target, organization:) }

  def remove_administrative_roles
    Users::AdminAccountWriter.new(
      user: target, organization:, actor: target, attributes: { system_role_ids: [] }
    )
  end

  %w[pending suspended blocked deleted].each do |status|
    it "does not count a #{status} administrator as a replacement" do
      candidate = create(:user, status:, system_roles: [administrator_role])
      create(:organization_membership, user: candidate, organization:, account_status: :active)

      writer = remove_administrative_roles

      expect(writer.save).to be(false)
      expect(target.errors[:system_role_ids]).to be_present
      expect(target.reload).to be_admin
    end
  end

  it 'does not count a soft-deleted administrator as a replacement' do
    candidate = create(:user, system_roles: [administrator_role], deleted_at: Time.current)
    create(:organization_membership, user: candidate, organization:, account_status: :active)

    expect(remove_administrative_roles.save).to be(false)
    expect(target.reload).to be_admin
  end

  it 'allows role removal when another active administrator can access the organization' do
    candidate = create(:user, system_roles: [administrator_role])
    create(:organization_membership, user: candidate, organization:, account_status: :active)

    staff = create(:system_role, :system, code: 'staff')
    writer = Users::AdminAccountWriter.new(
      user: target, organization:, actor: target, attributes: { system_role_ids: [staff.id] }
    )

    expect(writer.save).to be(true)
    expect(target.reload).not_to be_admin
    expect(candidate.reload).to be_admin
  end
end
