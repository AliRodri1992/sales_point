# frozen_string_literal: true

# Displays the saved-state and browser conditions whenever a collapse regression occurs.
# This keeps asynchronous failures diagnosable without weakening the expectation.
module SidebarBrowserExpectations
  FOCUS_STATE_SCRIPT = <<~JS.freeze
    (() => {
      const element = document.activeElement
      const toggle = document.getElementById('sidebarToggle')
      return { tag: element?.tagName, id: element?.id, inert: element?.inert,
        toggleInert: !!toggle?.closest('[inert]'), toggleVisibility: getComputedStyle(toggle).visibility,
        toggleDisabled: toggle?.disabled, documentFocused: document.hasFocus(),
        viewport: window.innerWidth, events: window.sidebarFocusTrace }
    })()
  JS

  FOCUS_TRACE_SCRIPT = <<~JS.freeze
    window.sidebarFocusTrace = []
    const trace = (type, target) => {
      const sidebar = document.getElementById('adminSidebar')
      const content = document.getElementById('adminDashboardContent')
      window.sidebarFocusTrace.push([type, target?.id || target?.tagName,
        document.activeElement?.id || document.activeElement?.tagName,
        sidebar.classList.contains('sidebar-open'), content.inert, sidebar.inert])
    }
    for (const event of ['pointerdown', 'pointerup', 'click', 'focusin', 'focusout']) {
      document.addEventListener(event, e => trace(e.type, e.target), true)
    }
    document.addEventListener('click', e => {
      if (!e.target.closest('#sidebarToggle, #sidebarCloseButton, #sidebarOverlay')) return
      requestAnimationFrame(() => trace('frame', e.target))
    }, true)
  JS

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

  def expect_sidebar_flyout_links
    return if page.has_css?('#adminSidebarFlyout a[href]', wait: 5)

    details = page.evaluate_script(<<~JS)
      (() => {
        const menu = document.getElementById('adminSidebarFlyout')
        const summary = document.querySelector('#adminSidebar .sidebar-catalog > summary')
        return {
          html: menu?.outerHTML?.slice(0, 1500),
          links: menu?.querySelectorAll('a[href]')?.length,
          visible: menu ? getComputedStyle(menu).visibility : null,
          summaryExpanded: summary?.getAttribute('aria-expanded')
        }
      })()
    JS
    raise RSpec::Expectations::ExpectationNotMetError,
          "Expected visible sidebar flyout links: #{details.inspect}"
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
    unless page.has_css?('#adminSidebar.sidebar-collapsed', wait: 5)
      raise RSpec::Expectations::ExpectationNotMetError,
            "Expected sidebar to collapse; browser state: #{sidebar_browser_state.inspect}"
    end

    Selenium::WebDriver::Wait.new(timeout: 4, interval: 0.05).until do
      page.evaluate_script(<<~JS)
        Math.abs(document.getElementById('adminSidebar').getBoundingClientRect().width - 80) < 1
      JS
    end
  rescue Selenium::WebDriver::Error::TimeoutError
    raise RSpec::Expectations::ExpectationNotMetError,
          "Sidebar transition did not complete: #{sidebar_browser_state.inspect}"
  end

  def expect_sidebar_toggle_focused
    Selenium::WebDriver::Wait.new(timeout: 4, interval: 0.05).until do
      page.evaluate_script("document.activeElement?.id === 'sidebarToggle'")
    end
  rescue Selenium::WebDriver::Error::TimeoutError
    focused = page.evaluate_script(FOCUS_STATE_SCRIPT)
    raise RSpec::Expectations::ExpectationNotMetError,
          "Drawer focus was not restored to the toggle: #{focused.inspect}"
  end

  def record_sidebar_focus_events
    page.execute_script(FOCUS_TRACE_SCRIPT)
  end
end
