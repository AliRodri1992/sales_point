# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier edit Uppy document uploader', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, organization:, user:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'initializes Uppy inside a single upload area on the edit documents step' do
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="5"]').click

    expect(page).to have_css('[data-supplier-form-target="step"]:not(.hidden) .supplier-edit-upload')
    expect(page).to have_css('.supplier-edit-upload .uppy-Dashboard-inner', wait: 20, count: 1)
    expect(page).to have_no_css('.supplier-edit-upload [data-supplier-edit-uppy-target="fallback"]',
                                visible: :all)
    expect(page).to have_no_css('.supplier-edit-upload [data-supplier-edit-uppy-target="retryButton"]:not([hidden])',
                                visible: :all)
    expect(page).to have_css('.supplier-edit-upload [data-supplier-edit-uppy-target="dashboard"]',
                             count: 1)

    dashboard_configuration = page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector('.supplier-edit-upload')
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, 'supplier-edit-uppy')
        const dashboard = controller.uppy.getPlugin('Dashboard')
        return { hideAfterFinish: dashboard.opts.hideProgressAfterFinish,
                 doneButton: dashboard.opts.doneButtonHandler }
      })()
    JS
    expect(dashboard_configuration).to eq('hideAfterFinish' => true, 'doneButton' => nil)
  end

  scenario 'shows completion underneath the dashboard without covering the loader' do
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="5"]').click
    expect(page).to have_css('.supplier-edit-upload .uppy-Dashboard-inner', wait: 20)

    page.execute_script(<<~JS)
      const element = document.querySelector('.supplier-edit-upload')
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, 'supplier-edit-uppy')
      controller.setStatus('Document uploaded successfully')
    JS

    expect(page).to have_css('.supplier-edit-upload__feedback[data-state="success"]',
                             text: 'Document uploaded successfully', visible: true)
    layout = page.evaluate_script(<<~JS)
      (() => {
        const dashboard = document.querySelector('.supplier-edit-upload .uppy-Dashboard-inner')
        const feedback = document.querySelector('.supplier-edit-upload__feedback')
        return {
          below: feedback.getBoundingClientRect().top >= dashboard.getBoundingClientRect().bottom,
          globalLoaderHidden: document.querySelector('#admin-action-loader').hidden
        }
      })()
    JS
    expect(layout).to eq('below' => true, 'globalLoaderHidden' => true)
  end
  scenario 'keeps the document preview below the sticky navbar while scrolling' do
    visit edit_admin_supplier_path(supplier)

    navigation = find('details[data-supplier-form-target="navigation"]')
    navigation.find('summary').click
    navigation.find('button[data-step-index="5"]').click

    expect(page).to have_css('.supplier-edit-upload .uppy-Dashboard-inner', wait: 20, count: 1)

    page.execute_script(<<~JS)
      const root = document.querySelector('.supplier-edit-upload')
      const controller = window.Stimulus.getControllerForElementAndIdentifier(root, 'supplier-edit-uppy')
      const data = new File(['%PDF-1.4 preview'], 'supplier-contract.pdf', { type: 'application/pdf' })
      controller.uppy.addFile({
        name: data.name, type: data.type, data, source: 'Local'
      })
      const file = controller.uppy.getFiles()[0]
      controller.uppy.getPlugin('Dashboard').toggleFileCard(true, file.id)
    JS

    expect(page).to have_css('.supplier-edit-upload .uppy-Dashboard-FileCard', visible: true)

    geometry = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector('.supplier-edit-upload [data-supplier-edit-uppy-target="dashboard"]')
        const card = panel.querySelector('.uppy-Dashboard-FileCard')
        const header = document.getElementById('adminTopbar')
        // Allow a realistic scroll even in a short fixture form/viewport.
        const spacer = document.createElement('div')
        spacer.style.height = '1200px'
        spacer.setAttribute('data-uppy-preview-test-spacer', '')
        document.body.appendChild(spacer)
        const initialHost = panel.getBoundingClientRect()
        window.scrollTo({ top: window.scrollY + initialHost.top - 35, behavior: 'instant' })
        const host = panel.getBoundingClientRect()
        const preview = card.getBoundingClientRect()
        const navbar = header.getBoundingClientRect()
        const overlap = {
          left: Math.max(navbar.left, preview.left),
          right: Math.min(navbar.right, preview.right),
          top: Math.max(navbar.top, preview.top),
          bottom: Math.min(navbar.bottom, preview.bottom)
        }
        const intersection = overlap.right > overlap.left && overlap.bottom > overlap.top
        const overlaidElement = intersection
          ? document.elementFromPoint((overlap.left + overlap.right) / 2,
                                      (overlap.top + overlap.bottom) / 2)
          : null
        return {
          contained: preview.left >= host.left - 1 && preview.right <= host.right + 1,
          isolated: getComputedStyle(panel).isolation === 'isolate',
          clipped: getComputedStyle(panel).contain.includes('paint'),
          overlapsNavbar: intersection,
          navbarOnTop: header.contains(overlaidElement)
        }
      })()
    JS

    expect(geometry).to eq(
      'contained' => true, 'isolated' => true, 'clipped' => true,
      'overlapsNavbar' => true, 'navbarOnTop' => true
    )
  end

end
