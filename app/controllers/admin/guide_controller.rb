# frozen_string_literal: true

module Admin
  class GuideController < ApplicationController
    SECTION_ORDER = %w[startup security catalogs suppliers purchasing finances communication].freeze

    layout 'admin_dashboard'
    before_action :authenticate_user!

    def show
      @sections = SECTION_ORDER.map do |section|
        key = "admin.user_manual.sections.#{section}"
        I18n.t(key, default: I18n.t(key, locale: :es))
      end
    end
  end
end
