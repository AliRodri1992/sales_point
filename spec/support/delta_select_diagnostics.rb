# frozen_string_literal: true

# Browser diagnostics for Stimulus dropdown regressions. The logger records
# native click/pointer events and the actual expanded/hidden state without
# adding actions to the application itself.
module DeltaSelectDiagnostics
  def click_branded_dropdown(wrapper)
    trigger = wrapper.find('button[aria-haspopup="listbox"]')
    page.execute_script(<<~JS, trigger)
      const trigger = arguments[0]
      const trace = []
      trigger.dataset.deltaSelectTraceId = 'active'
      window.__deltaSelectTrace = trace
      for (const name of ['pointerdown', 'mousedown', 'mouseup', 'click', 'focusin']) {
        trigger.addEventListener(name, () => {
          trace.push(name + ':capture:' + trigger.getAttribute('aria-expanded'))
        }, true)
        trigger.addEventListener(name, () => {
          trace.push(name + ':bubble:' + trigger.getAttribute('aria-expanded'))
        })
      }
      const observer = new MutationObserver(() => {
        trace.push('mutation:' + trigger.getAttribute('aria-expanded'))
      })
      observer.observe(trigger, { attributes: true, attributeFilter: ['aria-expanded'] })
      window.__deltaSelectTraceObserver = observer
    JS
    trigger.click
    expect_branded_dropdown_open(wrapper)
  end

  def expect_branded_dropdown_open(wrapper)
    return if wrapper.has_css?('button[aria-expanded="true"]', wait: 1)

    state = page.evaluate_script(<<~JS, wrapper)
      (function(wrapper) {
        const button = wrapper.querySelector('button[aria-haspopup="listbox"]')
        const menu = wrapper.querySelector('[role="listbox"]')
        const before = {
          ready: wrapper.dataset.deltaSelectReady,
          connected: wrapper.isConnected,
          controllers: wrapper.dataset.controller,
          button: button?.outerHTML.slice(0, 450),
          expanded: button?.getAttribute('aria-expanded'),
          hidden: menu?.hidden,
          options: menu?.querySelectorAll('[role="option"]').length,
          trace: window.__deltaSelectTrace || []
        }
        button?.click()
        return { before, syntheticClickExpanded: button?.getAttribute('aria-expanded'),
          syntheticClickHidden: menu?.hidden }
      })(arguments[0])
    JS
    raise RSpec::Expectations::ExpectationNotMetError, "Dropdown did not open: #{state.inspect}"
  end
end

RSpec.configure do |config|
  config.include DeltaSelectDiagnostics, type: :feature
end
