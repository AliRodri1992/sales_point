module LandingPage
  module Testimonials
    def self.all
      %i[laura carlos andrea].map do |key|
        testimonial(key)
      end
    end

    def self.testimonial(key)
      Testimonial.new(
        name: I18n.t("landing.testimonial_items.#{key}.name"),
        company: I18n.t("landing.testimonial_items.#{key}.company"),
        position: I18n.t("landing.testimonial_items.#{key}.position"),
        quote: I18n.t("landing.testimonial_items.#{key}.quote"),
        avatar: 'landing/avatar.svg'
      )
    end
  end
end
