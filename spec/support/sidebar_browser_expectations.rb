# frozen_string_literal: true

# Displays the saved-state and browser conditions whenever a collapse regression occurs.
# This keeps asynchronous failures diagnosable without weakening the expectation.
module SidebarBrowserExpectations
  def sidebar_browser_state
    page.evaluate_script(<<~JS)
      (() => {
        const sidebar = document.getElementById("adminSidebar")
        const toggle = document.getElementById("sidebarToggle")
        return {
          classes: sidebar?.className,
          ready: toggle?.dataset.sidebarReady,
          save: toggle?.dataset.sidebarSaveState,
          saveError: toggle?.dataset.sidebarSaveError,
          expanded: toggle?.getAttribute("aria-expanded"),
          viewport: window.innerWidth,
          alert: document.querySelector(".swal2-popup")?.textContent?.trim()
        }
      })()
    JS
  end

  def expect_sidebar_desktop_ready
    Selenium::WebDriver::Wait.new(timeout: 4, interval: 0.05).until do
      page.evaluate_script(<<~JS)
        (() => {
          const sidebar = document.getElementById('adminSidebar')
          return window.innerWidth >= 1024 && sidebar && !sidebar.inert
        })()
      JS
    end
  end

  def expect_sidebar_collapsed
    return if page.has_css?('#adminSidebar.sidebar-collapsed', wait: 5)

    raise RSpec::Expectations::ExpectationNotMetError,
          "Expected sidebar to collapse; browser state: #{sidebar_browser_state.inspect}"
  end
end
