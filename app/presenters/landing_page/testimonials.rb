module LandingPage
  module Testimonials
    KEYS = %w[alejandro beatriz carlos diana eduardo sofia].freeze

    def self.all
      KEYS.map do |key|
        Testimonial.new(
          name: I18n.t("landing.testimonial_items.#{key}.name"),
          company: I18n.t("landing.testimonial_items.#{key}.company"),
          position: I18n.t("landing.testimonial_items.#{key}.position"),
          quote: I18n.t("landing.testimonial_items.#{key}.quote"),
          avatar: nil
        )
      end
    end
  end
end
