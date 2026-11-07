# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branch directory and workspace', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let!(:central) do
    create(:branch, organization:, name: 'Central', code: 'CENTRAL', contact_email: 'central@example.com')
  end
  let!(:north) { create(:branch, organization:, name: 'North', status: false, code: 'NORTH') }

  before do
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  def result_text
    Nokogiri::HTML(response.body).at_css('turbo-frame#branches_list').text
  end

  it 'searches codes, email, accented locations and normalized mobile numbers safely' do
    phone = Phone.create!(phoneable: north, organization:, kind: 'mobile', primary: true, number: '+525512345678')
    %w[CENTRAL central@example.com].each do |term|
      get admin_branches_path(search: term)
      expect(result_text).to include(central.name)
      expect(result_text).not_to include(north.name)
    end
    get admin_branches_path(search: 'cuautitlan')
    expect(result_text).to include(central.name, north.name)
    get admin_branches_path(search: phone.number.last(8))
    expect(result_text).to include(north.name)
    expect(result_text).not_to include(central.name)
    get admin_branches_path(search: 'CODE5678')
    expect(result_text).not_to include(north.name)
    get admin_branches_path(search: '%_')
    expect(result_text).not_to include(central.name, north.name)
  end

  it 'combines filters and provides links that remove only the requested filter' do
    north.address.update!(city: 'Monterrey', state: 'Nuevo León')
    get admin_branches_path(status: 'inactive', country_id: north.address.country_id, state: 'Nuevo León',
                            city: 'Monterrey')
    expect(result_text).to include(north.name)
    expect(result_text).not_to include(central.name)
    document = Nokogiri::HTML(response.body)
    chips = document.css('#branch-filter-badges a[data-filter-key]')
    expect(chips.pluck('data-filter-key')).to contain_exactly('status', 'country_id', 'state', 'city')
    query = Rack::Utils.parse_nested_query(URI(document.at_css('[data-filter-key="status"]')['href']).query)
    expect(query).to include('city' => 'Monterrey', 'state' => 'Nuevo León')
    expect(query).not_to have_key('status')
  end

  it 'keeps a filter with no matches visible instead of widening the results' do
    get admin_branches_path(city: 'Missing city')
    expect(result_text).not_to include(central.name, north.name)
    expect(response.body).to include('City: Missing city')
    expect(response.body).to include('No branches match these filters')
  end

  it 'filters contact availability without duplicating branches' do
    Phone.create!(phoneable: north, organization:, kind: 'mobile', primary: true, number: '+525512345678')
    { 'with_phone' => north, 'without_phone' => central, 'with_email' => central,
      'without_email' => north }.each do |filter, expected|
      get admin_branches_path(contact: filter)
      expect(result_text).to include(expected.name)
      expect(result_text).not_to include(expected == central ? north.name : central.name)
    end
  end

  it 'counts assigned people once even when they have several active roles' do
    role = create(:system_role, :branch)
    create(:user_role, user: administrator, branch: central, system_role: role)
    create(:user_role, user: administrator, branch: central, system_role: create(:system_role, :branch))
    get admin_branches_path(team: 'assigned')
    expect(result_text).to include('1 assigned person', central.name)
    expect(result_text).not_to include(north.name)
    get admin_branches_path(team: 'unassigned')
    expect(result_text).to include(north.name)
    expect(result_text).not_to include(central.name)
  end

  it 'uses eligible people consistently for team counts and assignment filters' do
    person = create(:user)
    membership = create(:organization_membership, user: person, organization:)
    role = create(:system_role, :branch)
    create(:user_role, user: person, branch: central, system_role: role)
    [[membership, { account_status: 'suspended' }], [person, { status: 'suspended' }],
     [role, { status: 'inactive' }]].each do |record, attributes|
      membership.update!(account_status: 'active')
      person.update!(status: 'active')
      role.assign_attributes(status: 'active')
      role.save!(context: :status_transition)
      if record == role
        role.assign_attributes(attributes)
        role.save!(context: :status_transition)
      else
        record.update!(attributes)
      end
      get admin_branches_path(team: 'assigned')
      expect(result_text).not_to include(central.name)
      get admin_branches_path(team: 'unassigned')
      expect(result_text).to include(central.name, '0 assigned people')
    end
  end

  it 'applies inclusive local date boundaries and explains a reversed interval' do
    travel_to Time.zone.local(2026, 11, 6, 12) do
      central.update!(created_at: Time.zone.local(2026, 11, 5, 23, 59))
      north.update!(created_at: Time.zone.local(2026, 11, 6, 23, 59))
      get admin_branches_path(created_from: '2026-11-06', created_to: '2026-11-06')
      expect(result_text).to include(north.name)
      expect(result_text).not_to include(central.name)
      get admin_branches_path(created_from: '2026-11-07', created_to: '2026-11-06')
      expect(response.body).to include(I18n.t('admin.branch_workspace.invalid_period'))
      expect(result_text).not_to include(north.name)
    end
  end

  it 'ignores malformed dates and unknown enum values without raising errors' do
    get admin_branches_path(created_from: 'not-a-date', created_to: '2026-99-99', status: 'bad', contact: 'bad',
                            team: 'bad')
    expect(response).to have_http_status(:ok)
    expect(result_text).to include(central.name, north.name)
    get admin_branches_path(created_from: '0000-01-01', country_id: 'not-an-id', page: -20)
    expect(response).to have_http_status(:ok)
    expect(result_text).to include(central.name)
  end

  it 'returns stream updates for results, badges and dependent geographic options' do
    get admin_branches_path(search: 'CENTRAL'),
        headers: { 'Accept' => 'text/vnd.turbo-stream.html', 'X-Branch-Locations' => '1' }
    expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    expect(response.body).to include('target="branches_list"', 'target="branch-filter-badges"',
                                     'target="branch-filter-state"', 'target="branch-filter-city"')
  end

  it 'preserves directory context in view, edit, cancel and successful update links' do
    get admin_branch_path(central, search: 'CENTRAL', page: 2, per_page: 5)
    document = Nokogiri::HTML(response.body)
    expect(document.css('a').pluck('href')).to include(admin_branches_path(search: 'CENTRAL', page: '2', per_page: '5'))
    patch admin_branch_path(central, search: 'CENTRAL', per_page: 5),
          params: { branch: { notes: 'Reception closes at 18:00' } }
    expect(response).to redirect_to(admin_branches_path(search: 'CENTRAL', per_page: '5'))
    expect(central.reload.notes).to eq('Reception closes at 18:00')
  end

  it 'saves optional operational details and directions while ignoring tenant tampering' do
    other = create(:organization)
    post admin_branches_path, params: { branch: {
      name: 'New office', code: ' new-01 ', contact_email: ' OFFICE@EXAMPLE.COM ', notes: ' Deliveries after 09:00 ',
      organization_id: other.id, address_attributes: { street: 'Reforma', exterior_number: '100',
                                                       neighborhood: 'Centro', city: 'Ciudad de México', state: 'CDMX',
                                                       country_id: central.address.country_id, postal_code: '01000',
                                                       reference_notes: 'Side entrance' }
    } }
    expect(response).to have_http_status(:redirect), -> { Nokogiri::HTML(response.body).css('[role="alert"]').text }
    record = organization.branches.find_by!(name: 'New office')
    expect(record).to have_attributes(code: 'NEW-01', contact_email: 'office@example.com',
                                      notes: 'Deliveries after 09:00', status: true)
    expect(record.address.reference_notes).to eq('Side entrance')
  end

  it 'preserves entered values on invalid details and reports concurrent identifier conflicts' do
    post admin_branches_path,
         params: { branch: { name: 'Retained branch', code: 'BAD CODE', contact_email: 'not-an-email' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Retained branch', 'BAD CODE', 'not-an-email')
    allow_any_instance_of(Branch).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
    post admin_branches_path, params: { branch: { name: 'Concurrent', code: 'CONCURRENT' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.branch_workspace.identifier_conflict'))
  end

  it 'removes a registered mobile number through the branch form without deleting its history' do
    phone = Phone.create!(phoneable: central, organization:, kind: 'mobile', primary: true, number: '+525512345678')
    patch admin_branch_path(central),
          params: { branch: { phones_attributes: { '0' => { id: phone.id, _destroy: '1' } } } }
    expect(response).to have_http_status(:redirect)
    expect(phone.reload.deleted_at).to be_present
  end

  it 'does not leak other branch locations, contacts or operational totals to a restricted member' do
    reader = create(:user, :english)
    create(:organization_membership, user: reader, organization:)
    create(:user_role, user: reader, branch: central, system_role: create(:system_role, :branch))
    north.address.update!(state: 'Private region', city: 'Private city')
    sign_in reader
    get admin_branches_path
    expect(response.body).not_to include('Private region', 'Private city')
    expect(result_text).to include(central.name)
    expect(result_text).not_to include(north.name)
    get admin_branch_path(central)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Products with inventory')
    get admin_branch_path(north)
    expect(response).to have_http_status(:not_found)
  end
end
