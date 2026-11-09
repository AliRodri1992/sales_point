# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::UnitsOfMeasure', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }
  let!(:role) { create(:system_role, :system) }
  let!(:sat) { create(:sat_unit_key, code: 'H87') }
  let(:organization) { user.organization_memberships.first.organization }

  before do
    create(:organization_membership, user:)
    create(:user_role, user:, system_role: role)
    GranularPermissionCatalog.sync!
    Permission.where(code: GranularPermissionCatalog::ACTIONS.map { |action| "units_of_measure.#{action}" })
              .find_each { |permission| create(:system_role_permission, system_role: role, permission:) }
    sign_in user
  end

  after { sign_out user }

  it 'keeps collection and member routes distinct' do
    expect(admin_units_of_measure_path).to eq('/admin/units_of_measure')
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat)
    expect(admin_unit_of_measure_path(unit)).to eq("/admin/units_of_measure/#{unit.id}")
  end

  it 'shows the list, modal trigger and translated labels' do
    get admin_units_of_measure_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('unit_of_measure_modal', I18n.t('admin.units_of_measure.index.title'))
  end

  it 'blocks users without access permissions' do
    role.system_role_permissions.delete_all
    get admin_units_of_measure_path
    expect(response).to have_http_status(:forbidden)
  end

  it 'renders per-field errors and retains values without HTML5 required' do
    post admin_units_of_measure_path, params: {
      unit_of_measure: { code: 'KGM', name: '', abbreviation: 'kg', sat_unit_key_id: sat.id, decimal_precision: 0 }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('unit_of_measure_name_error', 'KGM')
  end

  it 'creates and updates a unit tied to SAT without any product relationship' do
    post admin_units_of_measure_path, params: {
      unit_of_measure: { code: 'PZA', name: 'Pieza', abbreviation: 'pza', sat_unit_key_id: sat.id,
                         decimal_precision: 0, status: 'active' }
    }
    unit = UnitOfMeasure.find_by!(code: 'PZA', organization:)
    expect(response).to have_http_status(:see_other)
    expect(unit.sat_unit_key).to eq(sat)

    patch admin_unit_of_measure_path(unit), params: { unit_of_measure: { name: 'Pieza individual' } }
    expect(unit.reload.name).to eq('Pieza individual')
  end

  it 'limits queries and updates to the selected organization' do
    other = create(:unit_of_measure, organization: create(:organization), sat_unit_key: sat, code: 'OTHER')
    get admin_units_of_measure_path
    expect(response.body).not_to include('OTHER')
    patch admin_unit_of_measure_path(other), params: { unit_of_measure: { name: 'Forbidden' } }
    expect(response).to have_http_status(:not_found)
  end

  it 'soft deletes without losing the record' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat)
    delete admin_unit_of_measure_path(unit)
    expect(response).to have_http_status(:see_other)
    expect(unit.reload.deleted_at).to be_present
  end

  it 'treats percent signs literally in search input' do
    create(:unit_of_measure, organization:, sat_unit_key: sat, name: 'Pieza')
    get admin_units_of_measure_path(search: '%')
    expect(response.body).to include(I18n.t('admin.units_of_measure.index.no_results'))
  end

  it 'does not reactivate a unit linked to an expired SAT key and renders field errors' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')
    sat.update!(valid_to: Date.yesterday)

    patch admin_unit_of_measure_path(unit), params: { unit_of_measure: { status: 'active' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('unit_of_measure_sat_unit_key_error')
    expect(unit.reload).to be_inactive
    expect(unit.deleted_at).to be_nil
  end

  it 'reactivates a unit with current SAT and keeps the historical key unchanged' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')

    patch admin_unit_of_measure_path(unit), params: { unit_of_measure: { status: 'active' } }
    expect(response).to have_http_status(:see_other)
    expect(unit.reload).to be_active
    expect(unit.sat_unit_key_id).to eq(sat.id)
  end

  it 'allows deactivating an active unit with expired SAT while retaining its record' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat)
    sat.update!(valid_to: Date.yesterday)

    patch admin_unit_of_measure_path(unit), params: { unit_of_measure: { status: 'inactive' } }
    expect(response).to have_http_status(:see_other)
    expect(unit.reload).to be_inactive
    expect(unit.deleted_at).to be_nil
  end

  it 'records the authenticated actor in the PaperTrail create update and logical deletion' do
    post admin_units_of_measure_path, params: {
      unit_of_measure: { code: 'AUD', name: 'Audit unit', abbreviation: 'aud',
                         sat_unit_key_id: sat.id, decimal_precision: 0, status: 'active' }
    }
    unit = UnitOfMeasure.find_by!(code: 'AUD', organization:)
    expect(unit.versions.last.whodunnit).to eq(user.id.to_s)

    patch admin_unit_of_measure_path(unit), params: { unit_of_measure: { status: 'inactive' } }
    expect(unit.reload.versions.last.whodunnit).to eq(user.id.to_s)

    delete admin_unit_of_measure_path(unit)
    expect(unit.reload.versions.last.whodunnit).to eq(user.id.to_s)
    expect(unit.deleted_at).to be_present
  end
  it 'keeps expired SAT keys selectable as historical filters for the current organization' do
    archived = create(:unit_of_measure, organization:, sat_unit_key: sat, code: 'HIST')
    current_key = create(:sat_unit_key, code: 'KGM')
    create(:unit_of_measure, organization:, sat_unit_key: current_key, code: 'LIVE')
    sat.update!(valid_to: Date.yesterday)

    get admin_units_of_measure_path(sat_health: 'invalid')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('HIST', I18n.t('admin.units_of_measure.sat.invalid'))
    expect(response.body).not_to include('LIVE')

    get admin_units_of_measure_path(sat_unit_key_id: sat.id)
    expect(response.body).to include('HIST')
    expect(response.body).not_to include('LIVE')

    sat.update!(deleted_at: Time.current)
    get admin_units_of_measure_path(sat_health: 'invalid')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(archived.code, sat.code)
    expect(archived.reload.sat_unit_key).to eq(sat)
  end

  it 'shows only the organizations linked SAT keys in the filter, keeping create options unrestricted' do
    unused = create(:sat_unit_key, code: 'ZZ91')
    create(:unit_of_measure, organization:, sat_unit_key: sat, code: 'LOCAL')
    create(:unit_of_measure, organization: create(:organization), sat_unit_key: unused, code: 'FOREIGN')

    get admin_units_of_measure_path
    expect(response.body).to include('H87')
    expect(response.body).not_to include('ZZ91')

    get new_admin_unit_of_measure_path
    expect(response.body).to include('ZZ91')
  end
  it 'renders editing a unit with expired SAT inside the requested Turbo modal frame' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat, status: 'inactive')
    sat.update!(valid_to: Date.yesterday)

    get edit_admin_unit_of_measure_path(unit), headers: { 'Turbo-Frame' => 'unit_of_measure_modal' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('unit_of_measure_modal')
    expect(response.body).to include('unit-measure-modal-title')
    expect(response.body).to include(I18n.t('admin.units_of_measure.sat.invalid_hint'))
  end

  it 'retains list query parameters when returning Turbo Stream updates' do
    create(:unit_of_measure, organization:, sat_unit_key: sat, code: 'ACTIVE', status: 'active')
    target = create(:unit_of_measure, organization:, sat_unit_key: sat,
                                      code: 'INACTIVE', status: 'inactive')
    headers = { 'Accept' => 'text/vnd.turbo-stream.html' }
    query = { status: 'inactive', sort: 'code', direction: 'desc', per_page: 10 }

    patch admin_unit_of_measure_path(target, query), params: {
      unit_of_measure: { name: 'Renamed inactive unit' }
    }, headers:
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Renamed inactive unit', 'status=inactive', 'sort=code')
    expect(response.body).not_to include('ACTIVE</code>')

    delete admin_unit_of_measure_path(target, query), headers:
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('status=inactive', 'sort=code')
    expect(response.body).to include(I18n.t('admin.units_of_measure.index.no_results'))
  end

end
