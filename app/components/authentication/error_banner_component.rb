# frozen_string_literal: true

module Authentication
  class ErrorBannerComponent < ViewComponent::Base
    delegate :icon, :class_names, to: :view_context

    def initialize(resource:)
      super()
      @resource = resource
    end

    private

    attr_reader :resource

    def visible?
      # Don't show banner if SweetAlert2 is handling the error
      return false if view_context.flash[:swal_message].present?

      resource.errors.any? || view_context.flash[:alert].present?
    end

    def message
      view_context.flash[:alert].presence ||
        resource.errors.full_messages.to_sentence
    end
  end
end
