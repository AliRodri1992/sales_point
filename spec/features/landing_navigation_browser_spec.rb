# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Landing navigation', type: :feature, js: true do
  before do
    create(:language, :english)
    create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
    create(:language, code: 'ko', name: '한국어', flag_iso: 'kr')
    visit root_path
    page.driver.browser.manage.add_cookie(name: 'terminal_language', value: 'en')
  end

  after { page.driver.browser.manage.window.resize_to(1400, 900) }

  scenario 'opens mobile navigation, closes with Escape and reaches sign in' do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit root_path
    find('[data-navbar-target="button"]').click
    expect(page).to have_css('[data-navbar-target="button"][aria-expanded="true"]')
    within '#landing-mobile-menu' do
      expect(page).to have_link('Sign in', href: new_user_session_path)
      expect(page).to have_link('Start', href: new_user_registration_path)
    end
    find('[data-navbar-target="button"]').send_keys(:escape)
    expect(page).to have_no_css('#landing-mobile-menu', visible: true)
    expect(page).to have_css('[data-navbar-target="button"]:focus')
    find('[data-navbar-target="button"]').click
    within('#landing-mobile-menu') { click_link 'Sign in' }
    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_css('#user_email')
  end

  scenario 'supports keyboard language selection inside the compact menu' do
    page.driver.browser.manage.window.resize_to(768, 1024)
    visit root_path
    find('[data-navbar-target="button"]').click
    find('#landing-mobile-button').click
    expect(page).to have_css('#landing-mobile-button[aria-expanded="true"]')
    expect(page).to have_css('#landing-mobile-languages [aria-pressed="true"]:focus')
    find('#landing-mobile-languages [aria-pressed="true"]').send_keys(:escape)
    expect(page).to have_css('#landing-mobile-button[aria-expanded="false"]:focus')
    expect(page).to have_css('#landing-mobile-menu', visible: true)
    find('#landing-mobile-button').click
    within('#landing-mobile-languages') { click_button 'Español' }
    expect(page).to have_css('html[lang="es"]')
    expect(page).to have_css('h1', text: 'El punto de venta')
    find('[data-navbar-target="button"]').click
    find('#landing-mobile-button').click
    expect(page).to have_css('#landing-mobile-languages button[data-language="es"][aria-pressed="true"]:focus')
    find('#landing-mobile-languages button[data-language="es"]').send_keys(:arrow_down)
    expect(page).to have_css('#landing-mobile-languages button[data-language="ko"]:focus')
  end

  scenario 'keeps the desktop language selector accessible without duplicate identifiers' do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit root_path
    expect(page).to have_link('Solution')
    find('#landing-desktop-button').click
    expect(page).to have_css('#landing-desktop-button[aria-expanded="true"]')
    find('#landing-desktop-languages [aria-pressed="true"]').send_keys(:escape)
    expect(page).to have_css('#landing-desktop-button[aria-expanded="false"]:focus')
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const ids = [...document.querySelectorAll('[id]')].map(element => element.id)
        return new Set(ids).size === ids.length
      })()
    JS
  end

  scenario 'keeps the logo and preview content inside their containers at all audited widths' do
    visit root_path
    [320, 390, 768, 1440].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      expect(page.evaluate_script(<<~JS)).to be(true), "Overflow at #{width}px"
        (() => {
          const header = document.querySelector('header').getBoundingClientRect()
          const logo = document.querySelector('header a[href="/"]').getBoundingClientRect()
          const cards = [...document.querySelectorAll('[data-landing-preview-card]')]
          return logo.top >= header.top && logo.bottom <= header.bottom &&
            document.documentElement.scrollWidth <= innerWidth &&
            cards.every(card => card.scrollWidth <= card.clientWidth)
        })()
      JS
    end
  end

  scenario 'closes compact navigation before scrolling to an unobstructed FAQ heading' do
    page.driver.browser.manage.window.resize_to(768, 1024)
    visit root_path
    find('[data-navbar-target="button"]').click
    within('#landing-mobile-menu') { click_link 'FAQ' }
    expect(page).to have_no_css('#landing-mobile-menu', visible: true)
    Selenium::WebDriver::Wait.new(timeout: 5).until do
      page.evaluate_script(<<~JS)
        (() => {
          const section = document.querySelector('#faq').getBoundingClientRect()
          const title = document.querySelector('#faq h2').getBoundingClientRect()
          const header = document.querySelector('header').getBoundingClientRect()
          return section.top >= 79 && section.top <= 81 && title.top > header.bottom
        })()
      JS
    end
    find('#faq summary', match: :first).send_keys(:enter)
    expect(page).to have_css('#faq details[open]')
  end

  scenario 'leaves testimonials stable until manually advancing with the keyboard' do
    page.driver.browser.manage.window.resize_to(320, 740)
    visit root_path
    carousel = find('[data-controller="testimonials-carousel"]')
    expect(carousel).to have_css('[data-testimonials-carousel-target="status"]', text: '1 / 2')
    expect(carousel).to have_css('article', count: 3)
    sleep 5.2 # Longer than the old automatic interval; reading must not change the slide.
    expect(carousel).to have_css('[data-testimonials-carousel-target="status"]', text: '1 / 2')
    carousel.find('[data-action="testimonials-carousel#next"]').send_keys(:enter)
    expect(carousel).to have_css('[data-testimonials-carousel-target="status"]', text: '2 / 2')
    expect(carousel).to have_css('article', count: 3)
    carousel.find('[data-action="testimonials-carousel#previous"]').click
    expect(carousel).to have_css('[data-testimonials-carousel-target="status"]', text: '1 / 2')
  end
end
