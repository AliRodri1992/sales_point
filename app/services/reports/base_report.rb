# frozen_string_literal: true

module Reports
  class BaseReport
    attr_reader :scope, :organization, :user, :locale

    def initialize(scope:, organization:, user:, locale: I18n.locale)
      @scope = scope
      @organization = organization
      @user = user
      @locale = locale
    end

    def title
      raise NotImplementedError
    end

    def columns
      raise NotImplementedError
    end

    def each_row(&block)
      scope.each(&block)
    end

    def filename
      "#{self.class.name.demodulize.underscore.delete_suffix('_report')}_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
    end
  end
end
