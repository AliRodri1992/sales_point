# frozen_string_literal: true

module Landing
  class PricingCardComponent < ViewComponent::Base
    def initialize(name:, price:, description:, features:, featured: false)
      super()
      @name = name
      @price = price
      @description = description
      @features = features
      @featured = featured
    end

    private

    attr_reader :name, :price, :description, :features, :featured

    def badge?
      featured
    end

    def card_classes
      class_names(
        "relative flex h-full flex-col justify-between rounded-2xl bg-white p-8",
        featured ? "border-2 border-emerald-600 shadow-md" : "border border-slate-200 shadow-sm"
      )
    end

    def button_classes
      class_names(
        "mt-8 block w-full rounded-xl py-3 text-center text-sm font-medium transition",
        featured ? "bg-emerald-600 text-white shadow-lg shadow-emerald-100 hover:bg-emerald-700" : "border border-slate-200 text-slate-700 hover:bg-slate-50"
      )
    end

    def plan_button_text
      I18n.t("landing.pricing.choose_plan")
    end
  end
end