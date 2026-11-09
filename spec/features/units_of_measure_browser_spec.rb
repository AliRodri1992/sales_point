# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Units of measure modal and responsive flows', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }
  let!(:sat_key) { create(:sat_unit_key, code: 'H87', description: 'Piece') }

  before do
    create(:organization_membership, organization:, user: administrator)
    Warden.test_mode!
    login_as(administrator, scope: :user)
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Warden.test_reset!
  end

  scenario 'validates fields, selects an SAT key, creates, views and edits in modals' do
    visit admin_units_of_measure_path
    within('main > header') { click_link 'New unit' }
    expect(page).to have_css('turbo-frame#unit_of_measure_modal [role="dialog"]', wait: 10)
    expect(page).to have_css('turbo-frame#unit_of_measure_modal.flex')

    fill_in 'unit_of_measure_code', with: 'BR_PCE'
    fill_in 'unit_of_measure_abbreviation', with: 'pc'
    click_button 'Create unit'
    expect(page).to have_css('#unit_of_measure_name_error', wait: 10)
    expect(page).to have_css('#unit_of_measure_name[aria-invalid="true"]')
    expect(page).to have_field('unit_of_measure_code', with: 'BR_PCE')

    fill_in 'unit_of_measure_name', with: 'Browser piece'
    sat_dropdown = find('#unit_of_measure_sat_unit_key_id', visible: :all).find(:xpath, '..')
    sat_dropdown.find('button[aria-haspopup="listbox"]').click
    sat_dropdown.find('[role="option"]', text: /H87.*Piece/).click
    expect(find('#unit_of_measure_sat_unit_key_id', visible: :all).value).to eq(sat_key.id.to_s)
    expect(page).to have_field('unit_of_measure_name', with: 'Browser piece')

    click_button 'Create unit'
    expect(page).to have_css('turbo-frame#unit_of_measure_modal.hidden', visible: :all, wait: 10)
    expect(page).to have_css('#units_of_measure_list', text: 'Browser piece', wait: 10)

    unit = organization.units_of_measure.find_by!(code: 'BR_PCE')
    expect(unit.sat_unit_key_id).to eq(sat_key.id)

    within('turbo-frame#units_of_measure_list tr', text: 'Browser piece') do
      find('a[aria-label="View details"]').click
    end
    expect(page).to have_css('turbo-frame#unit_of_measure_modal [role="dialog"]', text: 'Browser piece', wait: 10)
    within('turbo-frame#unit_of_measure_modal') { click_link 'Edit' }
    expect(page).to have_field('unit_of_measure_name', with: 'Browser piece', wait: 10)

    fill_in 'unit_of_measure_name', with: 'Browser piece revised'
    click_button 'Save changes'
    expect(page).to have_css('#units_of_measure_list', text: 'Browser piece revised', wait: 10)
    expect(unit.reload.name).to eq('Browser piece revised')
  end

  scenario 'keeps the centered modal in the viewport at mobile and desktop widths, closing with Escape' do
    [320, 390, 768, 1440].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      visit admin_units_of_measure_path
      within('main > header') { click_link 'New unit' }
      expect(page).to have_css('turbo-frame#unit_of_measure_modal.flex [role="dialog"]', wait: 10)

      bounds = page.evaluate_script(<<~JS)
        (() => {
          const panel = document.querySelector('#unit_of_measure_modal [role="dialog"]')
          const frame = document.querySelector('#unit_of_measure_modal')
          const rect = panel.getBoundingClientRect()
          return { left: rect.left, right: rect.right,
                   viewport: window.innerWidth, centered: getComputedStyle(frame).justifyContent }
        })()
      JS
      expect(bounds['left']).to be >= -1
      expect(bounds['right']).to be <= bounds['viewport'] + 1
      expect(bounds['centered']).to eq('center')

      find('#unit_of_measure_code').send_keys(:escape)
      expect(page).to have_css('turbo-frame#unit_of_measure_modal.hidden', visible: :all, wait: 10)
    end
  end
  scenario 'shows SAT fiscal issues and rejects reactivation with a retired key' do
    unit = create(:unit_of_measure, organization:, sat_unit_key: sat_key, status: 'inactive', code: 'HIST')
    sat_key.update!(valid_to: Date.yesterday)

    visit admin_units_of_measure_path
    expect(page).to have_css('#units_of_measure_list', text: 'SAT not current', wait: 10)
    click_link 'Units with SAT issues'
    # The row existed before clicking the summary card. Wait for the actual
    # Turbo navigation to complete rather than matching stale list content.
    expect(page).to have_css('#units-sat-health option[value="invalid"]:checked',
                             visible: :all, wait: 10)
    expect(page).to have_css('#units_of_measure_list', text: 'HIST', wait: 10)
    expect(page).to have_css('turbo-frame#unit_of_measure_modal', visible: :all, wait: 10)

    within('turbo-frame#units_of_measure_list tr', text: 'HIST') do
      find('a[aria-label="Edit"]').click
    end
    unless page.has_css?('turbo-frame#unit_of_measure_modal [role="dialog"]', wait: 5)
      frame = page.evaluate_script("document.querySelector('#unit_of_measure_modal')?.outerHTML")
      warn("UOM EDIT MODAL TRACE: url=#{current_url} frame=#{frame.to_s[0, 1200]}")
    end
    expect(page).to have_css('turbo-frame#unit_of_measure_modal [role="dialog"]', wait: 10)
    expect(page).to have_text('reactivation requires a current SAT code')

    status_dropdown = find('#unit_of_measure_status', visible: :all).find(:xpath, '..')
    status_dropdown.find('button[aria-haspopup="listbox"]').click
    status_dropdown.find('[role="option"]', text: 'Active').click
    click_button 'Save changes'

    expect(page).to have_css('#unit_of_measure_sat_unit_key_error', wait: 10)
    expect(unit.reload).to be_inactive
    expect(unit.deleted_at).to be_nil

    sat_key.update!(valid_to: Date.tomorrow)
    click_button 'Save changes'
    expect(page).to have_css('turbo-frame#unit_of_measure_modal.hidden', visible: :all, wait: 10)
    expect(unit.reload).to be_active
  end

  scenario 'searches a large official SAT catalog without duplicating options in the modal' do
    now = Time.current
    SatUnitKey.insert_all!((1..350).map do |number|
      { code: format('Z%04d', number), description: "Bulk key #{number}",
        created_at: now, updated_at: now }
    end)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    visit admin_units_of_measure_path
    within('main > header') { click_link 'New unit' }
    expect(page).to have_css('turbo-frame#unit_of_measure_modal.flex [role="dialog"]', wait: 10)

    select_control = find('#unit_of_measure_sat_unit_key_id', visible: :all).find(:xpath, '..')
    expect(page.evaluate_script("document.querySelector('#unit_of_measure_sat_unit_key_id').options.length")).to be >= 351
    select_control.find('button[aria-haspopup="listbox"]').click
    select_control.find('input[type="search"]').set('Z0350')
    expect(select_control).to have_css('[role="option"]:not([hidden])', text: 'Z0350', wait: 10)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    Rails.logger.info("Units of measure SAT dropdown benchmark: 350 additional keys in #{(elapsed * 1000).round}ms")
  end
end
