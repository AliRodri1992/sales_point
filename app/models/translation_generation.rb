# frozen_string_literal: true

class TranslationGeneration < ApplicationRecord
  belongs_to :language
  belongs_to :source_language, class_name: 'Language', optional: true
  belongs_to :actor, class_name: 'User', optional: true
  has_many :translates, dependent: :nullify

  enum :status,
       {
         pending: 'pending',
         processing: 'processing',
         completed: 'completed',
         failed: 'failed',
         cancelled: 'cancelled'
       },
       validate: true

  validates :provider, :provider_configuration_version, :source_catalog_version, :status, presence: true

  scope :active, -> { where(status: %i[pending processing]) }

  def self.enqueue_for!(language, actor: nil, force: false)
    source_language = Language.not_deleted.find_by(code: I18n.default_locale.to_s)
    source_code = source_language&.code || I18n.default_locale.to_s
    source_catalog_version = TranslationCatalog.version_for(source_code)
    provider = TranslationProviders::LibreTranslateProvider

    return create_completed_for_source!(language, source_language, actor, provider, source_catalog_version) if source_language&.id == language.id

    existing = active.find_by(language: language, source_catalog_version: source_catalog_version)
    return existing if existing && !force

    generation = create!(
      language: language,
      source_language: source_language,
      actor: actor,
      provider: provider.provider_name,
      provider_configuration_version: provider.configuration_version,
      source_catalog_version: source_catalog_version
    )
    begin
      TranslationGenerationJob.perform_later(generation.id)
    rescue StandardError => e
      generation.update!(last_error: "Job enqueue failed: #{e.message}".truncate(10_000))
      Rails.logger.error("[TranslationGeneration] enqueue failed for #{generation.id}: #{e.message}")
    end
    generation
  rescue ActiveRecord::RecordNotUnique
    active.find_by!(language: language, source_catalog_version: source_catalog_version)
  end

  def retryable?
    failed? || cancelled?
  end

  def mark_processing!
    with_lock do
      return false if completed? || cancelled?

      update!(status: :processing, started_at: started_at || Time.current, last_error: nil)
    end
    true
  end

  def mark_failed!(error)
    with_lock { update!(status: :failed, last_error: error.to_s.truncate(10_000)) }
  end

  def mark_cancelled!
    with_lock do
      return false if completed?

      update!(status: :cancelled, cancelled_at: Time.current)
    end
    true
  end

  def self.create_completed_for_source!(language, source_language, actor, provider, source_catalog_version)
    create!(
      language: language,
      source_language: source_language,
      actor: actor,
      provider: provider.provider_name,
      provider_configuration_version: provider.configuration_version,
      source_catalog_version: source_catalog_version,
      status: :completed,
      completed_at: Time.current
    )
  end

  private_class_method :create_completed_for_source!
end
