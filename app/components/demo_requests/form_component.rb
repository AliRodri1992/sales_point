# frozen_string_literal: true

module DemoRequests
  class FormComponent < ViewComponent::Base
    THEMES = [
      %w[emerald #059669 #0d9488], %w[sapphire #1e40af #1d4ed8], %w[sky #0284c7 #0369a1],
      %w[lime #84cc16 #65a30d], %w[olive #556b2f #3f5115], %w[yellow #fbc02d #f9a825],
      %w[gold #d4af37 #aa820a], %w[orange #f97316 #ea580c], %w[magenta #e21a84 #e21a84],
      %w[rose #fbcfe8 #f48fb1], %w[mint #a7f3d0 #34d399], %w[cherry #db2777 #be185d],
      %w[violet #7c3aed #6d28d9], %w[teal #0d9488 #0f766e], %w[indigo #4f46e5 #4338ca],
      %w[cyan #06b6d4 #0891b2], %w[fuchsia #d946ef #c026d3], %w[ruby #dc2626 #b91c1c],
      %w[bronze #854d0e #713f12], %w[slate #475569 #334155]
    ].freeze

    def initialize(demo_request:, notice: nil)
      super()
      @demo_request = demo_request
      @notice = notice
    end

    private

    attr_reader :demo_request, :notice

    def field_classes(attribute)
      base = 'demo-request__input appearance-none block w-full rounded-xl border px-3 py-1.5'
      base += ' text-xs shadow-sm transition-all placeholder:text-slate-400 focus:outline-none focus:ring-1'

      class_names(base, field_state_classes(attribute))
    end

    def field_state_classes(attribute)
      if demo_request.errors[attribute].any?
        'border-rose-400 bg-rose-50 focus:border-rose-500 focus:ring-rose-500'
      else
        'border-slate-200 bg-white focus:border-emerald-500 focus:ring-emerald-500'
      end
    end

    def error_for(attribute)
      helpers.error_message_for(demo_request, attribute)
    end
  end
end
