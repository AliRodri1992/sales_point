# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier calendar browser workflow', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'places the selected day agenda before the scrollable month grid on mobile' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_supplier_path(supplier, tab: 'schedules')

    expect(page).to have_css('[data-calendar-day-details]', visible: true)
    agenda_order = page.evaluate_script(<<~JS)
      const agenda = document.querySelector('[data-calendar-day-details]').closest('aside')
      return agenda ? getComputedStyle(agenda).order : null
    JS
    expect(agenda_order).to eq('1')
    expect(page).to have_css('[role="region"][tabindex="0"]', visible: true)
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario 'creates and edits a dated event in the accessible side drawer' do
    branch
    calendar_params = { tab: 'schedules', calendar_month: '2026-10',
                        calendar_selected_day: '2026-10-23' }
    visit admin_supplier_path(supplier, calendar_params)

    find('header button[data-action="supplier-calendar#open"]').click
    expect(page).to have_css('[data-supplier-calendar-target="drawer"][aria-hidden="false"]')
    expect(page).to have_no_css('.deltin-launcher', visible: true)
    expect(find('[name="supplier_event[starts_at]"]').value).to start_with('2026-10-23')

    find('[name="supplier_event[title]"]').set('Special delivery')
    branch_select = find('[name="supplier_event[branch_id]"]', visible: :all)
    branch_dropdown = branch_select.find(:xpath, '..')
    branch_dropdown.find('button[aria-haspopup="listbox"]').click
    expect(branch_dropdown).to have_css('button[aria-expanded="true"]')
    expect_stable_option_on_focus(branch_dropdown, marker: 'calendar')
    expect(branch_dropdown).to have_css('[role="option"]', text: branch.name)
    branch_dropdown.find('[role="option"]', text: branch.name, exact_text: true).click
    expect(branch_dropdown).to have_css('button[aria-expanded="false"]')
    expect(branch_select.value).to eq(branch.id.to_s)
    find('[data-supplier-calendar-target="submit"]').click

    expect(page).to have_css('[data-calendar-event]', text: 'Special delivery')
    expect(page).to have_css('[data-calendar-day-details]', text: 'Special delivery')

    find('[data-calendar-event] a[data-action="supplier-calendar#edit"]').click
    expect(page).to have_css('[data-supplier-calendar-target="heading"]', text: 'Edit event')
    expect(find('[name="supplier_event[title]"]').value).to eq('Special delivery')
    find('[name="supplier_event[title]"]').set('Updated delivery')
    find('[data-supplier-calendar-target="submit"]').click

    expect(page).to have_css('[data-calendar-event]', text: 'Updated delivery')
    expect(supplier.supplier_events.not_deleted.count).to eq(1)
  end

  scenario 'distinguishes visit types and completion states in the daily view' do
    supplier.supplier_events.create!(
      branch:, title: 'Completed delivery', kind: 'delivery', status: 'completed',
      starts_at: Time.zone.local(2026, 10, 23, 9), ends_at: Time.zone.local(2026, 10, 23, 10)
    )
    visit admin_supplier_path(supplier, tab: 'schedules', calendar_view: 'day', calendar_day: '2026-10-23')

    item = find('[data-day-item="event"][data-event-status="completed"]')
    expect(item).to have_text('Completed delivery')
    expect(item).to have_text('Completed')
    expect(item).to have_css('.bg-emerald-50', text: 'Delivery')
  end

  scenario 'closes the drawer with Escape and restores focus to the opener' do
    visit admin_supplier_path(supplier, tab: 'schedules')
    button = find('header button[data-action="supplier-calendar#open"]')
    button.click

    expect(page).to have_css('[data-supplier-calendar-target="drawer"][aria-hidden="false"]')
    find('[name="supplier_event[title]"]').send_keys(:escape)
    expect(page).to have_css('[data-supplier-calendar-target="drawer"][aria-hidden="true"]', visible: :all)
    expect(page.evaluate_script('document.activeElement.dataset.action')).to eq('supplier-calendar#open')
  end

  scenario 'shows an all-day multi-day visit on each affected daily calendar' do
    supplier.supplier_events.create!(
      branch:, title: 'Multi-day conference', kind: 'visit', status: 'scheduled',
      all_day: true,
      starts_at: Time.utc(2026, 10, 22, 12),
      ends_at: Time.utc(2026, 10, 25, 0)
    )

    (22..24).each do |day|
      query = { tab: 'schedules', calendar_view: 'day', calendar_day: format('2026-10-%02d', day) }
      visit admin_supplier_path(supplier, query)
      expect(page).to have_css('[data-calendar-day-details]', text: 'Multi-day conference')
    end

    query = { tab: 'schedules', calendar_view: 'day', calendar_day: '2026-10-25' }
    visit admin_supplier_path(supplier, query)
    expect(page).to have_no_css('[data-calendar-day-details]', text: 'Multi-day conference')
  end
end
