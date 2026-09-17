module LandingPage
  Feature = Data.define(:icon, :title, :description, :color)
  Testimonial = Data.define(:name, :company, :position, :quote, :avatar)
  Plan = Data.define(:name, :price, :description, :features, :featured)
  Question = Data.define(:question, :answer)

  module_function

  def features
    Features.all
  end

  def modules
    Modules.all
  end

  def testimonials
    Testimonials.all
  end

  def plans
    Plans.all
  end

  def questions
    Questions.all
  end
end
