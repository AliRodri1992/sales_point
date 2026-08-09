# frozen_string_literal: true

module Landing
  class PricingCardComponent < ViewComponent::Base
    def initialize(
      name:,
      price:,
      description:,
      features:,
      featured: false
    )
      @name = name
      @price = price
      @description = description
      @features = features
      @featured = featured
    end

    private

    attr_reader :name,
                :price,
                :description,
                :features,
                :featured

    def badge?
      featured
    end
  end
end