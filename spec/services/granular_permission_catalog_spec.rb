# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261103223000_add_granular_catalog_permissions')

RSpec.describe GranularPermissionCatalog do
  it 'provides every CRUD action in all five modules and is idempotent' do
    described_class.sync!
    codes = described_class::MODULES.keys.product(described_class::ACTIONS).map { |parts| parts.join('.') }
    expect(Permission.where(code: codes).count).to eq(30)
    expect { described_class.sync! }.not_to change(Permission, :count)
  end

  it 'backfills legacy access once without making access a permanent CRUD override' do
    access = create(:permission, code: 'categories.access')
    role = create(:system_role, :system)
    create(:system_role_permission, permission: access, system_role: role)
    migration = AddGranularCatalogPermissions.new
    migration.suppress_messages { migration.up }
    expect(role.permissions.pluck(:code)).to include('categories.index', 'categories.show', 'categories.create',
                                                     'categories.update', 'categories.destroy')
    role.system_role_permissions.joins(:permission).where(permissions: { code: 'categories.destroy' }).delete_all
    described_class.sync!
    expect(role.permissions.pluck(:code)).not_to include('categories.destroy')
  end
  %i[es en ko].each do |locale|
    it "translates all individual catalog actions in #{locale}" do
      codes = described_class::MODULES.keys.product(described_class::ACTIONS)
      attributes = %w[name description]
      codes.each do |prefix, action|
        attributes.each do |attribute|
          expect(I18n.exists?("admin.system_roles.permissions.#{prefix}_#{action}.#{attribute}", locale)).to be(true)
        end
      end
    end
  end
end
