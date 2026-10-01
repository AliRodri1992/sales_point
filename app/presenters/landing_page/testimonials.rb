module LandingPage
  module Testimonials
    KEYS = %w[alejandro beatriz carlos diana eduardo sofia].freeze

    def self.all
      KEYS.map do |key|
        Testimonial.new(
          name: I18n.t('landing.testimonial_items.#{key}.name', key:),
          company: I18n.t('landing.testimonial_items.#{key}.company', key:),
          position: I18n.t('landing.testimonial_items.#{key}.position', key:),
          quote: I18n.t('landing.testimonial_items.#{key}.quote', key:),
          avatar: nil
        )
      end
    end
  end
end
