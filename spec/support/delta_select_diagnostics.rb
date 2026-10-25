# frozen_string_literal: true

# Records the actual Stimulus lifecycle and closing events for a failed
# branded select interaction; a normal passing test has no diagnostic output.
module DeltaSelectDiagnostics
  def click_branded_dropdown(wrapper)
    page.execute_script(<<~JS, wrapper)
      arguments[0].dataset.deltaSelectTrace = 'true'
      window.__deltaSelectTrace = []
    JS
    wrapper.find('button[aria-haspopup="listbox"]').click
    return if wrapper.has_css?('button[aria-expanded="true"]', wait: 1)

    raise RSpec::Expectations::ExpectationNotMetError, dropdown_failure_state(wrapper).inspect
  end

  def dropdown_failure_state(wrapper)
    page.evaluate_script(<<~JS, wrapper)
      (function(wrapper) {
        const button = wrapper.querySelector('button[aria-haspopup="listbox"]')
        return { trace: window.__deltaSelectTrace, ready: wrapper.dataset.deltaSelectReady,
          triggerPresent: !!button, expanded: button?.getAttribute('aria-expanded'),
          hidden: wrapper.querySelector('[role="listbox"]')?.hidden }
      })(arguments[0])
    JS
  end
end

RSpec.configure { |config| config.include DeltaSelectDiagnostics, type: :feature }
