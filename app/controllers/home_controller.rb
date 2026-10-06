class HomeController < ApplicationController
  def index
    @landing_sections = LandingSection.enabled.order(:position)
    @landing_section_keys = @landing_sections.pluck(:key)

    @features = ::LandingPage.features
    @modules = ::LandingPage.modules
    @testimonials = ::LandingPage.testimonials
    @plans = ::LandingPage.plans
    @questions = ::LandingPage.questions
  end
end
