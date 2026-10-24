# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deltín floating assistant', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  scenario 'opens and closes the assistant by clicking on the puppy' do
    visit admin_dashboard_path

    expect(page).to have_css('.deltin-launcher', visible: true)
    expect(page).to have_css('.deltin-shell[data-assistant-ready="true"]')
    expect(page.evaluate_script(<<~JS)).to be(true)
      Boolean(window.Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('.deltin-shell'), 'deltin-assistant'
      ))
    JS

    find('.deltin-launcher').click
    expect(page).to have_css('#deltin-panel:not([hidden])', visible: true)
    expect(find('.deltin-launcher', visible: :all)['aria-expanded']).to eq('true')

    find('[data-deltin-assistant-target="closeButton"]').click
    expect(page).to have_css('#deltin-panel[hidden]', visible: :all)
    expect(find('.deltin-launcher', visible: :all)['aria-expanded']).to eq('false')

    find('.deltin-launcher').click
    expect(page).to have_css('#deltin-panel:not([hidden])', visible: true)
    find('[data-deltin-assistant-target="question"]').send_keys(:escape)
    expect(page).to have_css('#deltin-panel[hidden]', visible: :all)
  end

  scenario 'responds with actual guide content through its contextual panel' do
    visit admin_products_path
    find('.deltin-launcher').click

    find('[data-deltin-assistant-target="question"]').fill_in with: 'Dar de alta un producto'
    find('[data-deltin-assistant-target="sendButton"]').click

    expect(page).to have_css('[data-deltin-assistant-target="steps"] li', minimum: 1)
    expect(page).to have_link('Open illustrated procedure',
                              href: '/admin/guide#guide-products')
  end

  scenario 'closes from the overlay and opens contextual help from a quick question' do
    visit admin_products_path
    find('.deltin-launcher').click
    find('[data-action="click->deltin-assistant#quickAsk"]').first.click

    expect(page).to have_css('[data-deltin-assistant-target="result"]:not([hidden])')
    find('#deltin-panel > button[data-action="click->deltin-assistant#close"]').click

    expect(page).to have_css('#deltin-panel[hidden]', visible: :all)
    expect(find('.deltin-launcher', visible: :all)['aria-expanded']).to eq('false')
  end

  scenario 'keeps the assistant and online users buttons equally sized and separated' do
    visit admin_dashboard_path

    positions = page.evaluate_script(<<~JS)
      (() => {
        const puppy = document.querySelector('.deltin-launcher').getBoundingClientRect()
        const people = document.getElementById('onlineUsersButton').getBoundingClientRect()
        return { puppy: puppy.width, people: people.width, gap: puppy.left - people.right }
      })()
    JS

    expect(positions.fetch('puppy')).to eq(56)
    expect(positions.fetch('people')).to eq(56)
    expect(positions.fetch('gap').abs).to be >= 16
  end
end
