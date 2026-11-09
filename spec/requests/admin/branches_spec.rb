require 'rails_helper'

RSpec.describe 'Admin::Branches', type: :request do
  let(:system_admin_role) { create(:system_role, :system, code: 'administrator') }
  let(:branch_role) { create(:system_role, :branch) }
  let(:admin_user) { create(:user, system_roles: [system_admin_role]) }

  let(:country) { create(:country, iso_alpha2: 'MX') }

  let(:organization) { create(:organization) }

  before do
    create(:organization_membership, user: admin_user, organization:)
    sign_in admin_user
  end

  include SqlQueryRecorder

  describe 'GET /admin/branches/postal_suggestions' do
    it 'returns Mexican postal suggestions using the existing supplier lookup' do
      allow_any_instance_of(Suppliers::MexicanPostalLookup).to receive(:call).and_return(
        { found: true, state: 'Estado de México', municipality: 'Cuautitlán',
          neighborhoods: ['Centro'] }
      )

      get postal_suggestions_admin_branches_path, params: { country: 'MX', postal_code: '54800' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('found' => true, 'municipality' => 'Cuautitlán')
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'rejects invalid postal lookup parameters' do
      get postal_suggestions_admin_branches_path, params: { country: 'MX', postal_code: 'ABC' }
      expect(response).to have_http_status(:unprocessable_content)

      get postal_suggestions_admin_branches_path, params: { country: 'US', postal_code: '54800' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders postal assistance and country-specific address fields in the new branch form' do
      get new_admin_branch_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('supplier-postal-assist', 'supplier-country-fields',
                                       'branch-neighborhoods', 'postal_suggestions')
    end
  end

  describe 'GET /admin/branches' do
    it 'loads all visible branch phones in a batch', :n_plus_one do
      11.times { |index| create(:branch, organization:, name: "Performance Branch #{index}") }
      statements = recorded_sql_queries { get admin_branches_path }

      expect(response).to have_http_status(:ok)
      expect(statements.grep(/FROM "?phones"?/i).size).to be <= 2
    end

    before do
      BranchStatusTransition.unscoped.delete_all
      Branch.unscoped.delete_all
    end

    def listed_branch_names
      Nokogiri::HTML(response.body).css('.branch-table tbody .branch-name').map(&:text)
    end

    it 'renders the branches page' do
      create(:branch, organization:, name: 'Sucursal Centro')

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
    end

    it 'keeps page-size preferences accessible for 9 branches' do
      Array.new(9) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('table-per-page-branches')
      expect(response.body).to include('Sucursal 9')
    end

    it 'keeps page-size preferences accessible for exactly 10 branches' do
      Array.new(10) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('table-per-page-branches')
      expect(response.body).to include('Sucursal 10')
    end

    it 'paginates branches with 10 records by default when more than 10 exist' do
      Array.new(11) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('table-per-page-branches')
      expect(listed_branch_names.size).to eq(10)
      expect(response.body).to include('aria-current="page">1</span>')

      get admin_branches_path, params: { page: 2 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(1)
    end
    it 'allows selecting 5 records per page' do
      Array.new(11) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(5)

      get admin_branches_path, params: { per_page: 5, page: 3 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(1)
    end
    it 'allows selecting 15 records per page' do
      Array.new(16) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 15 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(15)

      get admin_branches_path, params: { per_page: 15, page: 2 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(1)
    end
    it 'respects explicit page size when exactly 10 branches exist' do
      Array.new(10) { |index| create(:branch, organization:, name: "Sucursal #{index + 1}") }

      get admin_branches_path, params: { per_page: 5 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(5)
      expect(response.body).to include('table-per-page-branches')

      get admin_branches_path, params: { per_page: 5, page: 2 }

      expect(response).to have_http_status(:ok)
      expect(listed_branch_names.size).to eq(5)
    end
    it 'sorts branches by name in ascending order' do
      create(:branch, organization:, name: 'Sucursal Norte')
      create(:branch, organization:, name: 'Sucursal Centro')

      get admin_branches_path, params: { sort: 'branches.name', direction: 'asc' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Sucursal Centro')).to be < response.body.index('Sucursal Norte')
    end

    it 'sorts branches by name in descending order' do
      create(:branch, organization:, name: 'Sucursal Centro')
      create(:branch, organization:, name: 'Sucursal Norte')

      get admin_branches_path, params: { sort: 'branches.name', direction: 'desc' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Norte')
      expect(response.body).to include('Sucursal Centro')
    end

    it 'sorts branches by address street' do
      center = create(:branch, organization:, name: 'Sucursal Centro')
      north = create(:branch, organization:, name: 'Sucursal Norte')
      center.address.update!(street: 'Reforma')
      north.address.update!(street: 'Zaragoza')

      get admin_branches_path, params: { sort: 'addresses.street', direction: 'asc' }

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Sucursal Centro')).to be < response.body.index('Sucursal Norte')
    end

    it 'does not expose branches outside the current user access' do
      sign_out admin_user
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      assigned_branch = create(:branch, organization:, name: 'Sucursal Asignada')
      create(:branch, organization:, name: 'Sucursal Restringida')
      create(:user_role, user: branch_user, system_role: branch_role, branch: assigned_branch)
      sign_in branch_user

      get admin_branches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Asignada')
      expect(response.body).not_to include('Sucursal Restringida')
    end
  end

  describe 'PATCH /admin/branches/:id/select' do
    it 'selects an active branch belonging to the current organization' do
      branch = create(:branch, organization:, status: true)

      patch select_admin_branch_path(branch)

      expect(response).to redirect_to(admin_dashboard_path)
    end

    it 'does not select a branch outside the current organization' do
      branch = create(:branch, organization: create(:organization), status: true)

      patch select_admin_branch_path(branch)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /admin/branches/new' do
    it 'renders the new branch screen without a modal for system administrators' do
      get new_admin_branch_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nueva sucursal')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include('action="/admin/branches"')
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from creating branches' do
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role,
                         branch: create(:branch, organization:, name: "Sucursal #{Branch.count + 1}"))
      sign_out admin_user
      sign_in branch_user

      get new_admin_branch_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /admin/branches/:id' do
    it 'keeps the operational status panel visually separated on the detail page' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')

      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      panel = document.at_css('section.branch-lifecycle-panel[aria-labelledby="branch-lifecycle-title"]')
      expect(panel).to be_present
      expect(panel.at_css('.branch-lifecycle-body .branch-lifecycle-heading')).to be_present
      expect(panel.at_css('.branch-lifecycle-description')).to be_present
      expect(document.at_css('.branch-detail-nav a[href="#branch-detail-lifecycle"]')).to be_present
    end

    it 'evaluates operational requirements once for a preparing branch detail' do
      branch = create(:branch, organization:, name: 'Nueva sucursal', operational_state: 'preparing')
      allow(Branches::LifecycleRequirements).to receive(:new).and_call_original

      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(Branches::LifecycleRequirements).to have_received(:new).once
      document = Nokogiri::HTML(response.body)
      expect(document.css('#branch-transition-target option').pluck('value'))
        .to contain_exactly('active', 'closed')
      expect(document.at_css('#branch-detail-lifecycle')).to be_present
    end

    it 'shows an assigned branch to a branch user' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sucursal Centro')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include('Av. Reforma')
    end

    it 'does not expose another branch to a branch user' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role,
                         branch: create(:branch, organization:, name: "Sucursal #{Branch.count + 1}"))
      sign_out admin_user
      sign_in branch_user

      get admin_branch_path(branch)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /admin/branches' do
    it 'shows validation messages below the corresponding fields' do
      post admin_branches_path, params: {
        branch: {
          name: '',
          phones_attributes: [{ number: '5551234567', country_code: 'MX', kind: 'mobile', primary: true }],
          status: true,
          address_attributes: {
            street: 'Av. Reforma',
            exterior_number: '100',
            city: 'Cuautitlán',
            state: 'Estado de México',
            country_id: country.id,
            postal_code: ''
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Nombre no puede estar vacío')
      expect(response.body).to include('Código postal no puede estar vacío')
    end

    it 'creates a branch, address and notification' do
      # New phones inherit the branch organization and require an active one.

      expect do
        post admin_branches_path, params: {
          branch: {
            name: 'Sucursal Centro',
            phones_attributes: [{ number: '5551234567', country_code: 'MX', kind: 'mobile', primary: true }],
            status: true,
            address_attributes: {
              street: 'Av. Reforma',
              exterior_number: '100',
              neighborhood: 'Centro',
              city: 'Cuautitlán',
              state: 'Estado de México',
              country_id: country.id,
              postal_code: '54800'
            }
          }
        }
      end.to change(Branch, :count).by(1)
                                   .and change(Address, :count).by(1)
                                                               .and change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(flash[:swal_message]).to eq(I18n.t('admin.branches.created'))
      created = Branch.order(:id).last
      expect(created).to be_preparing
      expect(created.branch_status_transitions.sole).to have_attributes(
        from_status: nil, to_status: 'preparing', changed_by: admin_user,
        reason: I18n.t('admin.branch_lifecycle.created_reason')
      )
      notification = admin_user.notifications.last
      expect(notification.event.params[:action]).to eq('created')
      expect(notification.event.params[:user]).to eq(admin_user)
      expect(notification.event.message).to eq(
        I18n.t('admin.shared.notifications.branch.created',
               name: 'Sucursal Centro',
               user: admin_user.display_name)
      )
    end

    it 'forbids branch-only users from creating branches' do
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role,
                         branch: create(:branch, organization:, name: "Sucursal #{Branch.count + 1}"))
      sign_out admin_user
      sign_in branch_user

      post admin_branches_path, params: { branch: { name: 'No autorizada', status: true } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'automatic identifiers and change history' do
    it 'does not permit changing the generated branch code through update parameters' do
      branch = create(:branch, organization:)
      original = branch.code

      patch admin_branch_path(branch), params: {
        branch: { name: 'Updated business location', code: 'MANUAL-CODE' }
      }

      expect(response).to redirect_to(admin_branches_path)
      expect(branch.reload.name).to eq('Updated business location')
      expect(branch.code).to eq(original)
    end

    it 'shows administrator-attributed changes to branch data' do
      branch = create(:branch, organization:)
      patch admin_branch_path(branch), params: { branch: { name: 'Changed branch name' } }
      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.branch_lifecycle.changes_title'))
      expect(response.body).to include('Changed branch name')
      expect(response.body).to include(admin_user.display_name)
    end
  end

  describe 'branch change history after soft deletion' do
    it 'retains phone and note changes after the records are retired' do
      branch = create(:branch, organization:)
      phone = branch.phones.create!(
        organization:, kind: 'mobile', primary: true,
        number: '+525512345678', country_code: 'MX'
      )
      note = branch.note_entries.create!(
        organization:, kind: 'general', body: 'Original operations note'
      )
      phone.update!(deleted_at: Time.current)
      note.update!(deleted_at: Time.current)

      get admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.branch_lifecycle.changes_title'))
      expect(response.body).to include(I18n.t('admin.branch_lifecycle.audit_removed'))
      expect(response.body).to include('Original operations note')
      expect(response.body).to include('+525512345678')
    end
  end

  describe 'accessible branch lifecycle controls' do
    it 'renders one status selector, one reason field and one confirmation action' do
      branch = create(:branch, organization:)
      get admin_branch_path(branch)

      document = Nokogiri::HTML(response.body)
      forms = document.css("form[action='#{transition_status_admin_branch_path(branch)}']")
      expect(forms.size).to eq(1)
      expect(forms.first['data-controller']).to include('branch-transition')
      expect(forms.first.at_css('select[name="to_status"]')).to be_present
      expect(forms.first.css('input[name="reason"]').size).to eq(1)
      expect(forms.first.at_css('select[name="to_status"]')['aria-describedby'])
        .to include('branch-transition-availability')
    end

    it 'describes blocked transitions before an administrator can submit them' do
      branch = create(:branch, organization:)
      create(:terminal, branch:, status: 'active')
      get admin_branch_path(branch)

      document = Nokogiri::HTML(response.body)
      option = document.at_css('#branch-transition-target option[value="suspended"]')
      expect(option['data-blocked']).to eq('true')
      expect(document.at_css('#branch-transition-availability')).to be_present
      expect(response.body).to include(I18n.t('admin.branch_lifecycle.blockers.active_terminals'))
    end
  end

  describe 'GET /admin/branches/:id/edit' do
    it 'renders the edit branch screen for a system administrator' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include('href="/admin/branches"')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(response.body).not_to include('data-branches-target="modal"')
    end

    it 'forbids branch-only users from editing branches' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      get edit_admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /admin/branches/:id' do
    it 'updates a branch and creates a notification' do
      branch = create(:branch, organization:, name: 'Sucursal Centro')

      expect do
        patch admin_branch_path(branch), params: {
          branch: {
            name: 'Sucursal Norte',
            address_attributes: { id: branch.address.id, city: 'Tlalnepantla' }
          }
        }
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(flash[:swal_message]).to eq(I18n.t('admin.branches.updated'))
      expect(branch.reload.name).to eq('Sucursal Norte')
      expect(branch.address.reload.city).to eq('Tlalnepantla')

      notification = admin_user.notifications.last
      expect(notification.event.params[:action]).to eq('updated')
      expect(notification.event.params[:user]).to eq(admin_user)
      expect(notification.event.message).to eq(
        I18n.t('admin.shared.notifications.branch.updated',
               name: 'Sucursal Norte',
               user: admin_user.display_name)
      )
    end

    it 'forbids branch-only users from updating branches' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      patch admin_branch_path(branch), params: { branch: { name: 'No autorizada' } }

      expect(response).to have_http_status(:forbidden)
      expect(branch.reload.name).not_to eq('No autorizada')
    end
  end

  describe 'DELETE /admin/branches/:id' do
    it 'soft deletes a branch and creates a notification with the actor' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}", operational_state: 'preparing')

      expect do
        delete admin_branch_path(branch)
      end.to change(Noticed::Notification, :count).by(1)

      expect(response).to redirect_to(admin_branches_path)
      expect(flash[:swal_message]).to eq(I18n.t('admin.branches.destroyed'))
      expect(branch.reload.deleted_at).to be_present

      notification = admin_user.notifications.last
      expect(notification.event.record).to eq(branch)
      expect(notification.event.params[:action]).to eq('destroyed')
      expect(notification.event.params[:user]).to eq(admin_user)
      expect(notification.event.message).to eq(
        I18n.t('admin.shared.notifications.branch.destroyed',
               name: branch.name,
               user: admin_user.display_name)
      )
    end

    it 'updates the list and shows a success toast for Turbo requests' do
      branch = create(:branch, organization:, name: 'Sucursal Centro', operational_state: 'preparing')

      delete admin_branch_path(branch), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('branches_list')
      expect(response.body).not_to include('Sucursal Centro')
      expect(response.body).to include(I18n.t('admin.branches.destroyed'))
      expect(branch.reload.deleted_at).to be_present
    end

    it 'forbids branch-only users from deleting branches' do
      branch = create(:branch, organization:, name: "Sucursal #{Branch.count + 1}")
      branch_user = create(:user)
      create(:organization_membership, user: branch_user, organization:)
      create(:user_role, user: branch_user, system_role: branch_role, branch:)
      sign_out admin_user
      sign_in branch_user

      delete admin_branch_path(branch)

      expect(response).to have_http_status(:forbidden)
      expect(branch.reload.deleted_at).to be_nil
    end
  end

  describe 'PATCH /admin/branches/:id/transition_status' do
    it 'requires a reason and does not mutate the branch' do
      office = create(:branch, organization:, name: 'Operational Branch')
      patch transition_status_admin_branch_path(office), params: { to_status: 'suspended', reason: '' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('admin.branch_lifecycle.errors.reason_required'))
      expect(office.reload).to be_active
      expect(office.branch_status_transitions.count).to eq(1)
    end

    it 'suspends a branch and records the actor and reason' do
      office = create(:branch, organization:, name: 'Operational Branch')
      patch transition_status_admin_branch_path(office),
            params: { to_status: 'suspended', reason: 'Temporary closure' }
      expect(response).to redirect_to(admin_branch_path(office))
      expect(office.reload).to be_suspended
      expect(office.status).to be(false)
      log = office.branch_status_transitions.last
      expect(log.changed_by).to eq(admin_user)
      expect(log.from_status).to eq('active')
      expect(log.to_status).to eq('suspended')
      expect(log.reason).to eq('Temporary closure')
    end

    it 'keeps a closed branch read-only and prevents changes after closure' do
      office = create(:branch, organization:, name: 'Closed Branch')
      patch transition_status_admin_branch_path(office),
            params: { to_status: 'closed', reason: 'No longer operating' }
      expect(office.reload).to be_closed

      get edit_admin_branch_path(office)
      expect(response).to have_http_status(:forbidden)

      patch admin_branch_path(office), params: { branch: { name: 'Reopened' } }
      expect(response).to have_http_status(:forbidden)
      expect(office.reload.name).to eq('Closed Branch')

      patch transition_status_admin_branch_path(office),
            params: { to_status: 'active', reason: 'Not permitted' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(office.reload).to be_closed
    end

    it 'disallows changing status through generic branch attributes' do
      office = create(:branch, organization:, name: 'Operational Branch')
      patch admin_branch_path(office), params: { branch: { status: false, operational_status: 'closed' } }
      expect(office.reload).to be_active
    end
  end

  describe 'PATCH /admin/branches/:id validation failures' do
    it 're-renders the edit form and preserves the branch when validation fails' do
      branch = create(:branch, organization:, name: 'Unchanged Branch')

      patch admin_branch_path(branch), params: { branch: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
      expect(branch.reload.name).to eq('Unchanged Branch')
    end

    it 'builds an address when an invalid update targets a branch without one' do
      branch = create(:branch, :without_address, organization:)

      patch admin_branch_path(branch), params: { branch: { name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Editar sucursal')
      expect(response.body).to include('address_attributes')
      expect(response.body).to include("action=\"/admin/branches/#{branch.id}\"")
    end
  end
  describe 'Branch model validation feedback' do
    it 'shows mandatory stars and disables native HTML5 form validation' do
      get new_admin_branch_path

      page = Nokogiri::HTML(response.body)
      form = page.at_css('form[action="/admin/branches"]')
      expect(form['novalidate']).to be_present
      expect(page.at_css('label[for="branch_name"]').text).to include('*')
      expect(page.at_css('label[for="branch_address_attributes_country_id"]').text).to include('*')
      expect(page.at_css('label[for="branch_address_attributes_street"]').text).to include('*')
      expect(page.at_css('input#branch_name')['required']).to be_nil
      expect(page.at_css('input#branch_address_attributes_street')['required']).to be_nil
      expect(page.at_css('input#branch_code')['pattern']).to be_nil
      expect(page.at_css('input#branch_code')['readonly']).to be_present
      expect(page.at_css('input#branch_code')['tabindex']).to be_nil
      expect(response.body).to include('branch-required-mark')
    end

    it 'rejects missing mandatory address on the server and displays its field error' do
      expect do
        post admin_branches_path, params: { branch: { name: 'New branch', status: true } }
      end.not_to change(Branch, :count)

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('#branch_address_error')).to be_present
      expect(document.at_css('#branch_address_error').text)
        .to include(I18n.t('admin.branch_workspace.location'))
    end

    it 'does not attribute a street error to the country dropdown' do
      branch = create(:branch, organization:)
      patch admin_branch_path(branch), params: {
        branch: { address_attributes: { id: branch.address.id, street: '' } }
      }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('#address_street_error')).to be_present
      country = document.at_css('select[name="branch[address_attributes][country_id]"]')
      expect(country['aria-invalid']).to eq('false')
      expect(document.at_css('#branch_address_error')).to be_nil
    end

    it 'keeps malformed email and address messages below each input' do
      post admin_branches_path, params: {
        branch: {
          name: 'AB', contact_email: 'bad-email',
          address_attributes: { street: '', city: '', country_id: '', postal_code: '' }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      %w[branch_name branch_contact_email address_street address_city address_country address_postal_code].each do |id|
        expect(document.at_css("##{id}_error")).to be_present
      end
      expect(document.at_css('.catalog-error')).to be_nil
      expect(document.text).not_to include(I18n.t('admin.catalog_design.fix_errors'))
    end

    it 'rejects removing a branch with assigned users' do
      branch = create(:branch, organization:, name: 'Assigned office', operational_state: 'preparing')
      person = create(:user)
      create(:organization_membership, user: person, organization:)
      create(:user_role, user: person, branch:, system_role: branch_role)

      delete admin_branch_path(branch)

      expect(response).to redirect_to(admin_branch_path(branch))
      expect(flash[:alert]).to be_present
      expect(branch.reload.deleted_at).to be_nil
    end
  end
  it 'explains branch soft removal and includes its name in the confirmation' do
    branch = create(:branch, organization:, name: 'Confirm removal', operational_state: 'preparing')
    get admin_branches_path

    document = Nokogiri::HTML(response.body)
    form = document.at_css("form[action='#{admin_branch_path(branch)}'][data-confirm-record]")
    expect(form).to be_present
    expect(form['data-confirm-record']).to eq(branch.name)
    expect(form['data-turbo-confirm']).to eq(I18n.t('admin.branch_workspace.remove_confirmation'))
  end
end
