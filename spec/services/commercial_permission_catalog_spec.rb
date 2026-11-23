# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261123000110_add_commercial_permissions')

RSpec.describe 'Commercial permission catalog', type: :service do
  let(:migration) { AddCommercialPermissions.new }

  def grant(role, *codes)
    codes.each do |code|
      permission = Permission.find_by(code:) || create(:permission, code:)
      create(:system_role_permission, system_role: role, permission:)
    end
  end

  it 'copies only existing product read rights and records automatic assignments once' do
    reader = create(:system_role, :system)
    listing_only = create(:system_role, :system)
    writer = create(:system_role, :system)
    grant(reader, *%w[products.access products.index products.show products.update])
    grant(listing_only, *%w[products.access products.index])
    grant(writer, *%w[products.access products.show products.create products.update])

    migration.suppress_messages { migration.up }

    expected_reads = %w[price_lists.access price_lists.index price_lists.show
                        promotions.access promotions.index promotions.show]
    expect(reader.permissions.pluck(:code) - %w[products.access products.index products.show products.update])
      .to match_array(expected_reads)
    expect(listing_only.permissions.pluck(:code) - %w[products.access products.index])
      .to match_array(%w[price_lists.access price_lists.index promotions.access promotions.index])
    expect(writer.permissions.pluck(:code)).to match_array(%w[products.access products.show products.create
                                                              products.update])
    expect(reader.permission_audit_events.find_by!(source: 'system').added_permission_codes)
      .to match_array(expected_reads)
    expect { migration.suppress_messages { migration.up } }.not_to change(SystemRolePermissionAuditEvent, :count)
  end

  it 'provisions the administrative role and preserves independent revocation when syncing the catalog' do
    administrator = create(:system_role, :system, code: 'administrator')
    reader = create(:system_role, :system)
    grant(reader, *%w[products.access products.index products.show])
    migration.suppress_messages { migration.up }

    expect(administrator.permissions.pluck(:code)).to include('price_lists.authorize_below_cost', 'promotions.resume')
    reader.system_role_permissions.find_by!(permission: Permission.find_by!(code: 'promotions.index')).destroy!

    expect { GranularPermissionCatalog.sync! }.not_to change { reader.permissions.order(:code).pluck(:code) }
  end

  it 'registers labeled actions for each supported language' do
    GranularPermissionCatalog.sync!
    codes = %w[price_lists promotions].product(%w[access index show create update archive activate pause
                                                 resume duplicate history]).map { |parts| parts.join('.') }
    codes += %w[price_lists.view_margin price_lists.authorize_below_cost]

    expect(Permission.where(code: codes).pluck(:code)).to match_array(codes)
    %i[es en ko].each do |locale|
      codes.each do |code|
        %w[name description].each do |attribute|
          expect(I18n.exists?("admin.system_roles.permissions.#{code.tr('.', '_')}.#{attribute}", locale)).to be(true)
        end
      end
    end
  end
end
