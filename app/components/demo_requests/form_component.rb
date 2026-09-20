# frozen_string_literal: true

module DemoRequests
  class FormComponent < ViewComponent::Base
    def initialize(demo_request:, notice: nil)
      super()
      @demo_request = demo_request
      @notice = notice
    end

    private

    attr_reader :demo_request, :notice

    def field_classes
      [
        'w-full rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-slate-900',
        'outline-none transition focus:border-[var(--brand)] focus:bg-white',
        'focus:ring-4 focus:ring-[var(--brand-light)]'
      ].join(' ')
    end
  end
end
