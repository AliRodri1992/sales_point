module LandingPage
  module Questions
    KEYS = %w[install offline migration commitment trial].freeze

    def self.all
      KEYS.map do |key|
        Question.new(
          question: I18n.t('landing.questions.%<key>s.question', key:),
          answer: I18n.t('landing.questions.%<key>s.answer', key:)
        )
      end
    end
  end
end
