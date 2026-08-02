# frozen_string_literal: true

module Authentication
  class ErrorBannerComponent < ViewComponent::Base
    def initialize(resource:)
      @resource = resource
    end

    private

    attr_reader :resource

    def visible?
      resource.errors.any? || helpers.flash[:alert].present?
    end

    def message
      helpers.flash[:alert].presence ||
        resource.errors.full_messages.to_sentence
    end
  end
end