# frozen_string_literal: true

class TranslationGenerationJob < ApplicationJob
  queue_as :translations

  retry_on TranslationProvider::TransientError,
           wait: ->(executions) { (2**executions).seconds + rand(0.0..1.0).seconds },
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(generation_id)
    generation = TranslationGeneration.find(generation_id)
    generation.update!(retry_count: [executions - 1, 0].max) if executions > 1
    TranslationGenerationService.new(generation).call
  rescue TranslationProvider::PermanentError => e
    generation&.mark_failed!(e.message)
  end
end
