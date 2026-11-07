# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Polymorphic notes in branch forms', type: :request do
  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let(:country) { create(:country, iso_alpha2: 'MX') }

  before do
    create(:organization_membership, user: administrator, organization:)
    sign_in administrator
  end

  it 'renders the polymorphic note field with the existing compatible parameter name' do
    get new_admin_branch_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('textarea#branch_note_body[name="branch[notes]"]')).to be_present
  end

  it 'persists a new branch note in the polymorphic table' do
    post admin_branches_path, params: {
      branch: {
        name: 'Sucursal Notas', status: true, notes: 'Use loading dock',
        address_attributes: {
          street: 'Reforma', exterior_number: '10', neighborhood: 'Centro',
          city: 'Cuautitlán', state: 'Estado de México', country_id: country.id, postal_code: '54800'
        }
      }
    }

    expect(response).to have_http_status(:redirect)
    branch = organization.branches.find_by!(name: 'Sucursal Notas')
    expect(branch.note_entries.general.sole.body).to eq('Use loading dock')
  end

  it 'updates a note without generating duplicate rows' do
    branch = create(:branch, organization:, notes: 'Original')

    patch admin_branch_path(branch), params: { branch: { notes: 'Updated' } }

    expect(response).to have_http_status(:redirect)
    expect(branch.reload.note_entries.general.sole.body).to eq('Updated')
  end
end
