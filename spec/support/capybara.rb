require 'capybara/rspec'
require 'selenium-webdriver'

Capybara.configure do |config|
  config.server = :puma, { Silent: true }
  config.default_max_wait_time = 5
  config.save_path = Rails.root.join('tmp/capybara')
  config.automatic_label_click = true
end

# ─────────────────────────────
# DRIVER PARA JS (Chrome headless)
# ─────────────────────────────

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--headless=new')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

# ─────────────────────────────
# DRIVER DEFAULT
# ─────────────────────────────

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_driver = :rack_test
