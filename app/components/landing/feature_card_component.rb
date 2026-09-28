# frozen_string_literal: true

module Landing
  class FeatureCardComponent < ViewComponent::Base
    def initialize(icon:, title:, description:, color: :emerald)
      super()
      @icon = icon
      @title = title
      @description = description
      @color = color
    end

    private

    attr_reader :icon, :title, :description, :color

    def icon_wrapper_classes
      {
        emerald: 'mb-6 flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600',
        teal: 'mb-6 flex h-12 w-12 items-center justify-center rounded-xl bg-teal-50 text-teal-600',
        dark_emerald: 'mb-6 flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700'
      }.fetch(color)
    end

    # icon may come in as a String (e.g. "bolt" from LandingPage::Features)
    # while the map below uses Symbol keys, so normalize before lookup.
    def icon_svg
      # rubocop:disable-next Layout/LineLength
      { bolt: '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>', inventory: '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 002 2h2a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/></svg>', chart: '<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>' }.fetch(icon.to_sym)
    end
  end
end
