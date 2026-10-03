# frozen_string_literal: true

RSpec.describe AdministratorPermissionProvisioner, type: :service do
  it 'provisions every active permission to the supplied role' do
    role = create(:system_role, :system, code: 'administrator')
    permissions = create_list(:permission, 3, status: :active)

    described_class.call(role:)

    expect(role.reload.permissions.where(status: :active).ids)
      .to match_array(permissions.map(&:id))
  end
end
