module LandingPage
  module Testimonials
    def self.all
      [
        Testimonial.new(
          name: I18n.t('landing.testimonial_items.laura.name'),
          company: I18n.t('landing.testimonial_items.laura.company'),
          position: I18n.t('landing.testimonial_items.laura.position'),
          quote: I18n.t('landing.testimonial_items.laura.quote'),
          avatar: 'landing/avatar.svg'
        ),
        Testimonial.new(
          name: I18n.t('landing.testimonial_items.carlos.name'),
          company: I18n.t('landing.testimonial_items.carlos.company'),
          position: I18n.t('landing.testimonial_items.carlos.position'),
          quote: I18n.t('landing.testimonial_items.carlos.quote'),
          avatar: 'landing/avatar.svg'
        ),
        Testimonial.new(
          name: I18n.t('landing.testimonial_items.andrea.name'),
          company: I18n.t('landing.testimonial_items.andrea.company'),
          position: I18n.t('landing.testimonial_items.andrea.position'),
          quote: I18n.t('landing.testimonial_items.andrea.quote'),
          avatar: 'landing/avatar.svg'
        )
      ]
    end
  end
end
