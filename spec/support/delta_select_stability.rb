# frozen_string_literal: true

# Keeps a browser-visible dropdown option attached through a focus refresh.
# Rebuilding an unchanged list mid-interaction produces detached Chrome nodes.
module DeltaSelectStability
  def expect_stable_option_on_focus(wrapper, marker:)
    page.execute_script(<<~JS, wrapper, marker)
      const dropdown = arguments[0]
      const option = dropdown.querySelector('[role="option"]:not([hidden])')
      option.dataset.stabilityMarker = arguments[1]
      dropdown.querySelector('button[aria-haspopup="listbox"]').focus()
    JS

    expect(wrapper).to have_css("[role='option'][data-stability-marker='#{marker}']")
  end
end

RSpec.configure { |config| config.include DeltaSelectStability, type: :feature }
