module LandingPage
  module Questions
    def self.all
      %i[install offline migration commitment trial].map do |key|
        question(key)
      end
    end

    def self.question(key)
      Question.new(
        question: I18n.t("landing.questions.#{key}.question"),
        answer: I18n.t("landing.questions.#{key}.answer")
      )
    end
  end
end
