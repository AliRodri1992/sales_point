# frozen_string_literal: true

RSpec.describe AdministratorPermissionProvisioner, type: :service do
  it 'provisions every active permission to the supplied role' do
    role = create(:system_role, :system, code: 'administrator')
    permissions = create_list(:permission, 3, status: :active)

    described_class.call(role:)

    expect(role.reload.permissions.where(status: :active).ids)
      .to match_array(permissions.map(&:id))
  end
  it 'assigns all supplier permissions declared by seeds to both protected roles' do
    roles = SystemRole::ADMINISTRATIVE_CODES.map do |code|
      create(:system_role, :system, code:)
    end
    seeds = Rails.root.join('db/seeds.rb').read
    definitions = seeds.split('DEFAULT_PERMISSIONS = [', 2).last.split('].freeze', 2).first
    codes = definitions.scan(/code: '(suppliers\.[a-z_.]+)'/).flatten

    expect(codes.size).to eq(20)
    codes.each { |code| create(:permission, code:, module_name: 'Proveedores') }

    roles.each do |role|
      expect(role.permissions.where(code: codes).pluck(:code)).to match_array(codes)
    end
  end

  it 'assigns new and reactivated permissions to existing administrators automatically' do
    roles = SystemRole::ADMINISTRATIVE_CODES.map do |code|
      create(:system_role, :system, code:)
    end
    created = create(:permission, code: 'suppliers.contacts.manage')
    inactive = create(:permission, code: 'suppliers.documents.manage', status: :inactive)

    roles.each do |role|
      expect(role.permissions).to include(created)
      expect(role.permissions).not_to include(inactive)
    end

    inactive.update!(status: :active)
    roles.each { |role| expect(role.permissions.reload).to include(inactive) }
  end

  it 'backfills existing active permissions when an administrator role is created later' do
    permission = create(:permission, code: 'suppliers.fiscal.view')
    role = create(:system_role, :system, code: 'administrator')

    expect(role.permissions).to include(permission)
    expect { described_class.call(role:) }.not_to change(SystemRolePermission, :count)
  end
end
