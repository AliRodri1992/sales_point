# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding scoped interface', type: :request do
  let(:user) { create(:user, :english) }
  let(:organization) { create(:organization, :with_settings) }

  before do
    create(:organization_membership, organization:, user:)
    role = create(:system_role, :system, code: 'administrator')
    create(:user_role, user:, system_role: role)
    sign_in user
  end

  it 'renders a named current step and explicitly mounted enhanced selects' do
    get admin_onboarding_path(step: 1)
    document = Nokogiri::HTML(response.body)
    expect(document.css('.onboarding-page [aria-current="step"]').count).to eq(2)
    expect(document.css('.onboarding-page [data-controller="delta-select"]').count).to eq(3)
    expect(document.at_css('#organization_name')['maxlength']).to eq('150')
    expect(document.at_css('[role="progressbar"]')).to be_present
  end

  it 'associates server validation with the control and retains select enhancement after 422' do
    patch admin_onboarding_path(step: 1), params: {
      organization: { name: '', tax_id: organization.tax_id, business_sector: 'grocery',
                      base_currency_id: organization.organization_settings.first.base_currency_id, timezone: 'UTC' }
    }
    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    field = document.at_css('#organization_name')
    expect(field['aria-invalid']).to eq('true')
    expect(document.at_css("##{field['aria-describedby']}").text).to start_with('Company name ')
    expect(document.at_css("##{field['aria-describedby']}").text).not_to include('too short')
    expect(document.css('.onboarding-page [data-controller="delta-select"]').count).to eq(3)
  end

  it 'creates a missing branch using the existing onboarding form' do
    country = create(:country, iso_alpha2: 'HK', iso_alpha3: 'HKG', iso_numeric: '344')
    expect do
      patch admin_onboarding_path(step: 2), params: {
        branch: { name: 'Initial branch', status: '1',
                  address_attributes: { street: 'Queens Road', city: 'Hong Kong', country_id: country.id } }
      }
    end.to change(organization.branches, :count).by(1)
    expect(response).to redirect_to(admin_onboarding_path(step: 3))
  end

  it 'does not accept a recovery intent on the wrong step' do
    expect do
      patch admin_onboarding_path(step: 1, intent: 'team'), params: {
        recovery: { first_name: 'Ana', last_name: 'Audit' }
      }
    end.not_to change(Employee, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'ignores forged organization and user identifiers while creating a profile' do
    foreign = create(:organization)
    other = create(:user)
    patch admin_onboarding_path(step: 5, intent: 'team'), params: {
      recovery: { first_name: 'Ana', last_name: 'Audit', organization_id: foreign.id, user_id: other.id }
    }
    expect(response).to redirect_to(admin_onboarding_path(step: 5))
    expect(organization.employees.find_by(email: user.email)).to be_present
    expect(foreign.employees).to be_empty
    expect(other.reload.employee_id).to be_nil
  end

  it 'enforces administrator permissions on recovery submissions' do
    user.user_roles.destroy_all
    expect do
      patch admin_onboarding_path(step: 5, intent: 'team'), params: {
        recovery: { first_name: 'Ana', last_name: 'Audit' }
      }
    end.not_to change(Employee, :count)
    expect(response).to have_http_status(:forbidden)
  end
end
