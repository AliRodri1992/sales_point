# frozen_string_literal: true

module Ui
  class SectionTitleComponent < ViewComponent::Base
    def initialize(
      title:,
      subtitle: nil,
      badge: nil,
      centered: true
    )
      @title = title
      @subtitle = subtitle
      @badge = badge
      @centered = centered
    end

    private

    attr_reader :title,
                :subtitle,
                :badge,
                :centered

    def wrapper_classes
      centered ? 'mx-auto max-w-3xl text-center' : ''
    end
  end
end