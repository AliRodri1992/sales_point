# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RolePermissionCatalogHelper, type: :helper do
  it 'groups translated database module names by their stable permission prefix' do
    permissions = [build(:permission, code: 'suppliers.create', module_name: 'Proveedores'),
                   build(:permission, code: 'suppliers.contacts.view', module_name: 'Suppliers')]
    expect(helper.grouped_role_permissions(permissions).map(&:first)).to eq(['suppliers'])
  end

  it 'keeps unknown modules and actions visible using their original labels' do
    permission = build(:permission, code: 'custom.special', module_name: 'Custom module', name: 'Special action')
    expect(helper.permission_module_key(permission)).to eq('Custom module')
    expect(helper.permission_action_label(permission)).to eq('Special action')
  end
end
