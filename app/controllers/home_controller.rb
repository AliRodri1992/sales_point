class HomeController < ApplicationController
  def index
    @features = ::LandingPage.features
    @modules = ::LandingPage.modules
    @testimonials = ::LandingPage.testimonials
    @plans = ::LandingPage.plans
    @questions = ::LandingPage.questions
  end
end
