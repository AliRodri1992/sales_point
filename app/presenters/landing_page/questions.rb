module LandingPage
  module Questions
    KEYS = %w[install offline migration commitment trial].freeze

    def self.all
      KEYS.map do |key|
        Question.new(
          question: I18n.t("landing.questions.#{key}.question"),
          answer: I18n.t("landing.questions.#{key}.answer")
        )
      end
    end
  end
end
