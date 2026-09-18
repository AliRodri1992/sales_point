module LandingPage
  module Questions
    def self.all
      [
        Question.new(
          question: I18n.t('landing.questions.install.question'),
          answer: I18n.t('landing.questions.install.answer')
        ),
        Question.new(
          question: I18n.t('landing.questions.offline.question'),
          answer: I18n.t('landing.questions.offline.answer')
        ),
        Question.new(
          question: I18n.t('landing.questions.migration.question'),
          answer: I18n.t('landing.questions.migration.answer')
        ),
        Question.new(
          question: I18n.t('landing.questions.commitment.question'),
          answer: I18n.t('landing.questions.commitment.answer')
        ),
        Question.new(
          question: I18n.t('landing.questions.trial.question'),
          answer: I18n.t('landing.questions.trial.answer')
        )
      ]
    end
  end
end
