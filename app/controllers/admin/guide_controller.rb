# frozen_string_literal: true

module Admin
  class GuideController < ApplicationController
    SECTION_ORDER = %w[startup security catalogs suppliers purchasing finances communication].freeze

    layout 'admin_dashboard'
    before_action :authenticate_user!

    def show
      @sections = SECTION_ORDER.map { |section| localized_section(section) }
    end

    private

    def localized_section(section)
      key = "admin.user_manual.sections.#{section}"
      source = I18n.t(key, locale: :es)
      translated = I18n.t(key, default: {})
      source.merge(translated).merge(topics: translated[:topics].presence || source[:topics])
    end
  end
end
