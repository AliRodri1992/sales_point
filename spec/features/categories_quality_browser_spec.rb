# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Categories modal workflows', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:administrator) { create(:user, :english, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, organization:, user: administrator)
    Warden.test_mode!
    login_as(administrator, scope: :user)
  end

  after do
    Warden.test_reset!
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  scenario 'shows a SweetAlert warning and retains the category and filters when removal is blocked' do
    category = create(:category, organization:, name: 'Groceries', code: 'groceries')
    create(:product, organization:, category:)

    page.driver.browser.manage.window.resize_to(1280, 900)
    visit admin_categories_path(search: category.name)
    find('tr', text: category.name).find('button[aria-label="Delete: Groceries"]').click
    find('.swal2-popup.delta-confirm-popup .delta-confirm-accept').click

    expect(page).to have_css('.swal2-popup.swal2-icon-warning[role="dialog"]',
                             text: I18n.t('admin.categories.in_use', locale: :en, raise: true), wait: 10)
    [1440, 768, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      expect_category_warning_layout
    end
    expect(page).to have_css('.swal2-confirm:focus', text: 'Close')
    within('.swal2-popup.swal2-icon-warning') do
      expect(page).to have_text('This category cannot be removed')
      click_button 'Close'
    end
    expect(page).to have_no_css('.swal2-popup', wait: 10)
    expect(page).to have_no_css('#categories_alert')
    expect(page).to have_field('category_search', with: category.name)
    expect(page).to have_css('turbo-frame#categories_list', text: category.name)
    expect(category.reload.deleted_at).to be_nil
  end

  scenario 'dismisses a blocked removal with Escape and allows another Turbo attempt' do
    category = create(:category, organization:, name: 'Groceries', code: 'groceries')
    create(:product, organization:, category:)
    visit admin_categories_path(search: category.name)

    2.times do
      trigger = find('tr', text: category.name).find('button[aria-label="Delete: Groceries"]')
      trigger.click
      find('.delta-confirm-accept').click
      expect(page).to have_css('.swal2-popup.swal2-icon-warning', text: 'This category cannot be removed')
      expect_category_warning_layout
      find('.swal2-confirm').send_keys(:escape)
      expect(page).to have_no_css('.swal2-popup')
      expect(page).to have_css('button[aria-label="Delete: Groceries"]:focus')
    end

    expect(category.reload.deleted_at).to be_nil
    expect(page).to have_field('category_search', with: category.name)
  end

  %w[es ko].each do |locale|
    scenario "keeps the #{locale} warning readable on mobile with enlarged text" do
      administrator.update!(language: create(:language, code: locale, name: locale, flag_iso: locale))
      category = create(:category, organization:, name: 'Groceries', code: 'groceries')
      create(:product, organization:, category:)
      visit admin_categories_path(search: category.name)
      label = I18n.t('admin.categories.index.delete', locale:, raise: true)
      find('tr', text: category.name).find("button[aria-label=\"#{label}: Groceries\"]").click
      find('.delta-confirm-accept').click

      expect(page).to have_css('.swal2-popup.swal2-icon-warning',
                               text: I18n.t('admin.categories.in_use', locale:, raise: true))
      page.driver.browser.manage.window.resize_to(320, 900)
      page.execute_script('document.documentElement.style.fontSize = "200%"')
      expect_category_warning_layout
      click_button I18n.t('admin.categories.show.close', locale:, raise: true)
      expect(page).to have_no_css('.swal2-popup')
      expect(category.reload.deleted_at).to be_nil
    end
  end

  scenario 'validates required fields and saves the description from the modal' do
    visit admin_categories_path
    click_link 'New category'
    expect(page).to have_css('turbo-frame#category_modal [role="dialog"]', wait: 10)

    fill_in 'category_code', with: 'browser_category'
    click_button 'Create category'
    expect(page).to have_css('#category_name_error', wait: 10)
    expect(page).to have_css('#category_name[aria-invalid="true"]')

    fill_in 'category_name', with: 'Browser category'
    fill_in 'category_description', with: 'Browser verified description'
    click_button 'Create category'

    expect(page).to have_css('turbo-frame#categories_list', text: 'Browser category', wait: 10)
    expect(organization.categories.find_by!(code: 'browser_category').description).to eq('Browser verified description')
  end

  scenario 'uses a wider two-column form on desktop and stacks fields on narrow screens' do
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit admin_categories_path
    click_link 'New category'
    expect(page).to have_css('turbo-frame#category_modal .categories-modal', wait: 10)

    desktop = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('#category_modal .categories-modal')
        const code = document.querySelector('#category_code').getBoundingClientRect()
        const name = document.querySelector('#category_name').getBoundingClientRect()
        return { width: panel.getBoundingClientRect().width, sameRow: Math.abs(code.top - name.top) < 4 }
      })()
    JS
    expect(desktop['width']).to be_between(600, 700)
    expect(desktop['sameRow']).to be(true)

    page.driver.browser.manage.window.resize_to(390, 844)
    stacked = page.evaluate_script(<<~JS)
      (() => {
        const code = document.querySelector('#category_code').getBoundingClientRect()
        const name = document.querySelector('#category_name').getBoundingClientRect()
        const panel = document.querySelector('#category_modal .categories-modal').getBoundingClientRect()
        return { stacked: name.top > code.bottom, fits: panel.width <= window.innerWidth }
      })()
    JS
    expect(stacked['stacked']).to be(true)
    expect(stacked['fits']).to be(true)
  end

  %w[es en ko].each do |locale|
    scenario "fits the compact edit form without scrolling on desktop and mobile in #{locale}" do
      administrator.update!(language: create(:language, code: locale, name: locale, flag_iso: locale)) unless locale == 'en'
      category = create(:category, organization:, name: 'Groceries', code: 'groceries')

      page.driver.browser.manage.window.resize_to(1280, 720)
      visit admin_categories_path
      label = I18n.t('admin.categories.index.edit', locale:, raise: true)
      find("a[aria-label=\"#{label}: Groceries\"]", visible: true).click
      expect(page).to have_css('#category_modal .categories-field--status button[aria-haspopup="listbox"]')

      desktop = category_edit_layout
      expect(desktop['firstRow']).to be(true)
      expect(desktop['secondRow']).to be(true)
      expect(desktop['footerRow']).to be(true)
      expect(desktop['fits']).to be(true)
      expect(desktop['touchTargets']).to be(true)

      page.driver.browser.manage.window.resize_to(390, 844)
      mobile = category_edit_layout
      expect(mobile['stacked']).to be(true)
      expect(mobile['fits']).to be(true)
      expect(mobile['touchTargets']).to be(true)

      page.driver.browser.manage.window.resize_to(390, 450)
      expect(category_edit_layout['canScroll']).to be(true)
      within('#category_modal') do
        fill_in 'category_name', with: 'Updated groceries'
        click_button I18n.t('admin.categories.form.update', locale:, raise: true)
      end
      expect(page).to have_no_css('#category_modal [role="dialog"]')
      expect(category.reload.name).to eq('Updated groceries')
    end
  end

  scenario 'retains sorting after a table header click without advanced filters' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    within('table.categories-table thead') { click_link 'Name' }

    expect(page).to have_css('turbo-frame#categories_list a.categories-filter-chip', text: 'Descending', wait: 10)
    expect(page).to have_no_css('details.categories-advanced')
    expect(page).to have_css('input#category_direction[type="hidden"][value="desc"]', visible: :all, wait: 10)

    fill_in 'category_search', with: 'groceries'
    expect(page).to have_css('turbo-frame#categories_list a.categories-filter-chip', text: 'Descending', wait: 10)
  end

  scenario 'preserves an active search after creating an unrelated category' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    fill_in 'category_search', with: 'groceries'
    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'groceries', wait: 10)

    click_link 'New category'
    fill_in 'category_code', with: 'new_unrelated'
    fill_in 'category_name', with: 'Cleaning'
    click_button 'Create category'

    expect(page).to have_field('category_search', with: 'groceries', wait: 10)
    expect(page).to have_no_css('turbo-frame#category_modal [role="dialog"]', wait: 10)
    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'groceries', wait: 10)
    expect(page).to have_css('turbo-frame#categories_list', text: 'Groceries', wait: 10)
    expect(page).to have_no_css('turbo-frame#categories_list a.categories-name-link', text: 'Cleaning')
    expect(organization.categories.find_by!(code: 'new_unrelated')).to be_present
  end

  scenario 'offers responsive sorting without restoring advanced filters' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')
    create(:category, organization:, name: 'Cleaning', code: 'cleaning')

    page.driver.browser.manage.window.resize_to(390, 844)
    visit admin_categories_path

    expect(page).to have_css('.categories-mobile-sort-field', visible: true)
    expect(page).to have_no_css('details.categories-advanced')
    within('.categories-mobile-sort-field') do
      find('button[aria-haspopup="listbox"]').click
      find('[role="option"]', text: 'Code · Descending').click
    end

    expect(page).to have_css('input#category_sort[value="code"]', visible: :all, wait: 10)
    expect(page).to have_css('input#category_direction[value="desc"]', visible: :all, wait: 10)
    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'Descending', wait: 10)

    page.driver.browser.manage.window.resize_to(768, 900)
    expect(page).to have_css('.categories-mobile-sort-field', visible: true)
  end

  scenario 'resets an outdated page query when changing filters within a Turbo Frame' do
    create_list(:category, 25, organization:)
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path(page: 3)
    expect(page).to have_css('.categories-directory[data-categories-current-page="3"]')

    fill_in 'category_search', with: 'Groceries'
    expect(page).to have_css('.categories-directory[data-categories-current-page="1"]', wait: 10)
    expect(page).to have_css('turbo-frame#categories_list a.categories-name-link', text: 'Groceries', wait: 10)
    expect(page.evaluate_script('new URL(window.location.href).searchParams.get("page")')).to be_nil
    expect(page.evaluate_script('new URL(window.location.href).searchParams.get("search")')).to eq('Groceries')
  end

  scenario 'tracks explicit pagination in the URL after a Turbo Frame navigation' do
    create_list(:category, 25, organization:)

    visit admin_categories_path
    within('turbo-frame#categories_list') { click_link '2' }

    expect(page).to have_css('.categories-directory[data-categories-current-page="2"]', wait: 10)
    expect(page.evaluate_script('new URL(window.location.href).searchParams.get("page")')).to eq('2')
  end

  scenario 'keeps page controls together, touchable and inside the viewport' do
    create_list(:category, 65, organization:)
    widths = [1440, 768, 390, 320]

    [1, 4].each do |current_page|
      visit admin_categories_path(page: current_page)
      widths.each do |width|
        page.driver.browser.manage.window.resize_to(width, 900)
        expect(page).to have_css('.categories-pagination-links[aria-label] [aria-current="page"]',
                                 text: current_page.to_s)
        expect_compact_category_pagination
      end
    end
    within('.categories-pagination-links') { click_link '5' }
    expect(page).to have_css('.categories-pagination-links [aria-current="page"]', text: '5')
  end

  scenario 'reassigns an inactive category through its modal and then removes it with filters intact' do
    source = create(:category, organization:, name: 'Groceries', code: 'groceries')
    product = create(:product, organization:, category: source)
    target = create(:category, organization:, name: 'Replacement')
    source.update!(status: :inactive)
    visit admin_categories_path(search: source.name, status: 'inactive')
    find('a[aria-label="Reassign references: Groceries"]', visible: true).click

    within('turbo-frame#category_modal') do
      expect(page).to have_text('1 product')
      click_button 'Reassign references'
      expect(page).to have_css('[data-server-field-error]', text: "can't be blank")
      find('button[aria-haspopup="listbox"]').click
      find('[role="option"]', text: target.name, exact_text: true).click
      click_button 'Reassign references'
    end
    expect(page).to have_no_css('turbo-frame#category_modal [role="dialog"]')
    expect(product.reload.category_id).to eq(target.id)
    expect(page).to have_field('category_search', with: source.name)
    expect(page).to have_select('category_status', selected: 'Inactive', visible: :all)
    expect(page).to have_no_css('.swal2-popup', wait: 10)

    find('button[aria-label="Delete: Groceries"]', visible: true).click
    find('.delta-confirm-accept').click
    expect(page).to have_no_css('a.categories-name-link', text: source.name)
    expect(source.reload.deleted_at).to be_present
    expect(product.reload.category_id).to eq(target.id)
  end

  scenario 'returns to the filtered catalog after a reassignment from the direct screen' do
    source = create(:category, organization:, name: 'Groceries')
    product = create(:product, organization:, category: source)
    target = create(:category, organization:, name: 'Replacement')
    source.update!(status: :inactive)
    visit references_admin_category_path(source, search: source.name, status: 'inactive')

    find('button[aria-haspopup="listbox"]').click
    find('[role="option"]', text: target.name, exact_text: true).click
    click_button 'Reassign references'

    expect(page).to have_current_path(admin_categories_path, ignore_query: true)
    expect(page).to have_field('category_search', with: source.name)
    expect(page).to have_select('category_status', selected: 'Inactive', visible: :all)
    expect(product.reload.category_id).to eq(target.id)
  end

  scenario 'searches live and renders a removable filter chip' do
    create(:category, organization:, name: 'Groceries', code: 'groceries')

    visit admin_categories_path
    fill_in 'category_search', with: 'groceries'

    expect(page).to have_css('turbo-frame#categories_list .categories-filter-chip', text: 'groceries', wait: 10)
    expect(page).to have_css('.categories-mobile-card', text: 'Groceries', visible: :all)
  end

  def category_edit_layout
    page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('#category_modal .categories-modal--edit')
        const [code, name, description, status] = ['#category_code', '#category_name', '#category_description',
          '.categories-field--status button[aria-haspopup="listbox"]'].map(selector => panel.querySelector(selector).getBoundingClientRect())
        const actions = [...panel.querySelectorAll('.categories-modal-actions > *')].map(el => el.getBoundingClientRect())
        const sameRow = (a, b) => Math.abs(a.top - b.top) < 4
        const box = panel.getBoundingClientRect()
        return {
          firstRow: sameRow(code, name), secondRow: sameRow(description, status),
          footerRow: actions.length === 3 && actions.every(action => sameRow(action, actions[0])),
          stacked: name.top > code.bottom && description.top > name.bottom && status.top > description.bottom,
          fits: panel.scrollHeight <= panel.clientHeight + 1 && panel.scrollWidth <= panel.clientWidth + 1 &&
            box.top >= 0 && box.bottom <= innerHeight && box.left >= 0 && box.right <= innerWidth,
          touchTargets: [code, name, description, status, ...actions].every(action => action.height >= 44),
          canScroll: panel.scrollHeight > panel.clientHeight && getComputedStyle(panel).overflowY === 'auto'
        }
      })()
    JS
  end

  def expect_category_warning_layout
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const popup = document.querySelector('.swal2-popup.swal2-icon-warning')
        const [icon, title, text, button] = ['.swal2-icon', '.swal2-title', '.swal2-html-container', '.swal2-confirm']
          .map(selector => popup.querySelector(selector).getBoundingClientRect())
        const box = popup.getBoundingClientRect()
        return Math.abs((icon.left + icon.right - box.left - box.right) / 2) < 2 &&
          icon.bottom < title.top && title.bottom < text.top && text.bottom < button.top &&
          box.left >= 0 && box.right <= innerWidth && popup.scrollWidth <= popup.clientWidth &&
          button.height >= 44 && getComputedStyle(popup.querySelector('.swal2-title')).textAlign === 'center' &&
          popup.getAttribute('aria-labelledby') === popup.querySelector('.swal2-title').id &&
          popup.getAttribute('aria-describedby') === popup.querySelector('.swal2-html-container').id
      })()
    JS
  end

  def expect_compact_category_pagination
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const group = document.querySelector('.categories-pagination-links')
        const boxes = [...group.querySelectorAll('a, [aria-current="page"]')].map(n => n.getBoundingClientRect())
        const children = [...group.children].map(n => n.getBoundingClientRect())
        return boxes.length <= 9 && boxes.every(b => b.width >= 44 && b.height >= 44 && b.left >= 0 && b.right <= innerWidth) &&
          children.slice(1).every((b, i) => b.top > children[i].top || b.left - children[i].right <= 12)
      })()
    JS
  end
end
