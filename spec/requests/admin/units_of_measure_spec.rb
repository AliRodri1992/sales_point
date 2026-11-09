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
end
