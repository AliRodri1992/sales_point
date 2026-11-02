# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Navbar branch selector authorization', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:branch_role) { create(:system_role, :branch, code: 'branch_operator') }

  before do
    create(:organization_membership, user:, organization:)
    sign_in user
  end

  def selector
    Nokogiri::HTML(response.body).at_css('[data-dashboard-selector]')
  end

  def selector_actions
    selector.css('[data-dashboard-selector-menu] form[action]').map { |form| form['action'] }
  end

  def assign_branch(branch, role: branch_role)
    create(:user_role, user:, system_role: role, branch:)
  end

  it 'only lists active branches assigned to the current non-administrator' do
    assigned = create(:branch, organization:, name: 'Sucursal Asignada')
    unavailable = create(:branch, organization:, name: 'Sucursal No Asignada')
    assign_branch(assigned)

    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(selector_actions).to contain_exactly(select_admin_branch_path(assigned))
    expect(selector.text).to include(assigned.name)
    expect(selector.text).not_to include(unavailable.name)
  end

  it 'allows multiple assigned branches without duplicates and orders them by name' do
    north = create(:branch, organization:, name: 'Sucursal Norte')
    center = create(:branch, organization:, name: 'Sucursal Centro')
    role2 = create(:system_role, :branch, code: 'branch_cashier')
    assign_branch(north)
    assign_branch(center)
    assign_branch(center, role: role2)

    get admin_dashboard_path

    expect(selector_actions).to eq([select_admin_branch_path(center), select_admin_branch_path(north)])
  end

  it 'excludes inactive, soft-deleted and other-organization branches' do
    allowed = create(:branch, organization:, name: 'Sucursal Disponible')
    inactive = create(:branch, organization:, name: 'Sucursal Inactiva', status: false)
    deleted = create(:branch, organization:, name: 'Sucursal Eliminada', deleted_at: Time.current)
    foreign = create(:branch, organization: create(:organization), name: 'Sucursal Externa')
    [allowed, inactive, deleted, foreign].each { |branch| assign_branch(branch) }

    get admin_dashboard_path

    expect(selector_actions).to contain_exactly(select_admin_branch_path(allowed))
  end

  it 'does not use deleted assignments or inactive roles' do
    valid = create(:branch, organization:, name: 'Sucursal Vigente')
    removed = create(:branch, organization:, name: 'Sucursal Revocada')
    inactive_role_branch = create(:branch, organization:, name: 'Sucursal Rol Inactivo')
    assign_branch(valid)
    assign_branch(removed).update!(deleted_at: Time.current)
    inactive_role = create(:system_role, :branch, code: 'inactive_branch_role')
    assign_branch(inactive_role_branch, role: inactive_role)
    inactive_role.update!(status: 'inactive')

    get admin_dashboard_path

    expect(selector_actions).to contain_exactly(select_admin_branch_path(valid))
  end

  it 'shows the empty selector when the user has no active branch assignments' do
    create(:branch, organization:, name: 'Sucursal Privada')

    get admin_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(selector_actions).to be_empty
    expect(selector.text).to include(I18n.t('admin.shared.branch_selector.empty'))
  end

  it 'rejects a manually submitted selection of a non-assigned branch' do
    allowed = create(:branch, organization:, name: 'Sucursal Propia')
    denied = create(:branch, organization:, name: 'Sucursal Ajena')
    assign_branch(allowed)

    patch select_admin_branch_path(denied)

    expect(response).to have_http_status(:not_found)
    get admin_dashboard_path
    expect(selector.at_css('summary').text).to include(allowed.name)
  end

  it 'falls back to a remaining branch when an assignment is revoked after selection' do
    revoked = create(:branch, organization:, name: 'Sucursal A')
    retained = create(:branch, organization:, name: 'Sucursal B')
    assignment = assign_branch(revoked)
    assign_branch(retained)
    patch select_admin_branch_path(revoked)
    expect(response).to redirect_to(admin_dashboard_path)

    assignment.update!(deleted_at: Time.current)
    get admin_dashboard_path

    expect(selector.at_css('summary').text).to include(retained.name)
    expect(selector_actions).to contain_exactly(select_admin_branch_path(retained))
    patch select_admin_branch_path(revoked)
    expect(response).to have_http_status(:not_found)
  end

  it 'preserves organization-wide access for administrators but excludes other organizations' do
    sign_out user
    admin = create(:user)
    create(:organization_membership, user: admin, organization:)
    create(:user_role, user: admin, system_role: create(:system_role, :system, code: 'administrator'))
    first = create(:branch, organization:, name: 'Sucursal Central')
    second = create(:branch, organization:, name: 'Sucursal Oriente')
    foreign = create(:branch, organization: create(:organization), name: 'Sucursal Externa')
    sign_in admin

    get admin_dashboard_path

    expect(selector_actions).to contain_exactly(select_admin_branch_path(first), select_admin_branch_path(second))
    expect(selector.text).not_to include(foreign.name)
  end
end
