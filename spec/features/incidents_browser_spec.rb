require 'rails_helper'

RSpec.describe 'Reporting an incident', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:reporter) { create(:user, :english) }
  let(:organization) { create(:organization) }

  before do
    create(:organization_membership, user: reporter, organization: organization)
    login_as(reporter, scope: :user)
  end

  after { Warden.test_reset! }

  it 'opens contextual help, selects an impact and submits a report' do
    visit new_admin_incident_path
    find('[data-section-help-trigger]', match: :first).click
    expect(page).to have_css('[data-section-help-panel]:not([hidden]) img[src*="portrait"]')
    find('.promotion-help-close', match: :first).click
    fill_in 'incident_description', with: 'Could not finish editing'
    find('summary[aria-labelledby="incident_blocks_operation_label"]').click
    click_button 'I could not continue'
    click_button 'Submit incident'
    expect(page).to have_text('Incident recorded')
    expect(page).to have_text('Could not finish editing')
    expect(page).to have_text('I could not continue')
  end
end
