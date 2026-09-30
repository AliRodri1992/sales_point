# frozen_string_literal: true

require 'digest'
require 'json'

class TranslationGenerationService
  BATCH_SIZE = 25
  PLACEHOLDER_PATTERN = /%{[^}]+}/.freeze

  def initialize(generation)
    @generation = generation
  end

  def call
    return if @generation.completed? || @generation.cancelled?

    @generation.mark_processing!

    source_language = @generation.source_language
    unless source_language
      fail_generation!('Source language is not configured')
      return
    end

    catalog = TranslationCatalog.new(source_language.code).call
    if catalog.empty?
      fail_generation!("Source catalog is missing for #{source_language.code}")
      return
    end

    current_version = TranslationCatalog.version_for(source_language.code)
    if current_version != @generation.source_catalog_version
      fail_generation!('Source catalog changed during generation; a new generation is required')
      return
    end

    TranslationStalenessDetector.call(@generation.language, catalog)

    skipped = catalog.count { |_key, value| non_translatable?(value) }
    @generation.update!(total_translations: catalog.size, skipped_translations: skipped)

    entries = catalog.reject { |_key, value| non_translatable?(value) }
    provider = provider_for(@generation.provider)
    source_code = provider_language_code(source_language)
    target_code = provider_language_code(@generation.language)

    entries.each_slice(BATCH_SIZE) do |batch|
      ensure_generation_active!
      process_batch(batch, provider, source_code, target_code)
    end

    @generation.with_lock do
      refresh_progress!
      @generation.update!(
        status: :completed,
        completed_at: Time.current,
        last_error: nil
      )
    end

    TranslationYamlSynchronizer.call(@generation.language)
    reload_i18n_backend!
    notify_generation('completed')
  rescue TranslationProvider::Error => e
    fail_generation!(e.message)
    raise if e.is_a?(TranslationProvider::TransientError)
  rescue StandardError => e
    fail_generation!(e.message)
    raise
  end

  def retry
    return @generation unless @generation.retryable?

    source = @generation.source_language
    if source && TranslationCatalog.version_for(source.code) != @generation.source_catalog_version
      return TranslationGeneration.enqueue_for!(@generation.language, actor: @generation.actor)
    end

    @generation.update!(status: :pending, cancelled_at: nil)
    TranslationGenerationJob.perform_later(@generation.id)
    @generation
  end

  def cancel
    @generation.mark_cancelled!
    notify_generation('cancelled')
  end

  private

  def process_batch(batch, provider, source_code, target_code)
    groups = batch.each_with_object({}) do |(key, value), result|
      next if Translate.exists?(language_id: @generation.language_id, key: key, deleted_at: nil)

      result[value] ||= []
      result[value] << key
    end

    deduplicated = groups.values.sum { |keys| [keys.length - 1, 0].max }
    @generation.increment!(:deduplicated_translations, deduplicated)
    return refresh_progress! if groups.empty?

    texts = groups.keys
    translated = provider.translate_many(
      texts: texts,
      source: source_code,
      target: target_code
    )

    ActiveRecord::Base.transaction do
      texts.zip(translated).each do |source_text, value|
        unless placeholders_valid?(source_text, value)
          raise TranslationProvider::InvalidResponseError,
                "Placeholder mismatch for translation batch"
        end

        groups.fetch(source_text).each do |key|
          Translate.create!(
            language: @generation.language,
            key: key,
            value: value,
            translation_generation: @generation,
            source_text_when_translated: source_text,
            source_text_digest: Digest::SHA256.hexdigest(source_text),
            translation_source: 'automatic'
          )
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end
    end

    refresh_progress!
  end

  def refresh_progress!
    completed = Translate.where(language_id: @generation.language_id, deleted_at: nil).count
    @generation.update!(completed_translations: completed)
  end

  def ensure_generation_active!
    @generation.reload
    return if @generation.processing?

    raise TranslationProvider::PermanentError, 'Translation generation is no longer active'
  end

  def fail_generation!(message)
    completed = Translate.where(language_id: @generation.language_id, deleted_at: nil).count
    failed = [@generation.total_translations - completed - @generation.skipped_translations, 0].max
    @generation.update!(failed_translations: failed)
    @generation.mark_failed!(message)
    notify_generation('failed')
  end

  def provider_for(name)
    case name
    when TranslationProviders::LibreTranslateProvider.provider_name
      TranslationProviders::LibreTranslateProvider.new
    else
      raise TranslationProvider::PermanentError, "Unknown translation provider: #{name}"
    end
  end

  def provider_language_code(language)
    mapping = JSON.parse(ENV.fetch('TRANSLATION_PROVIDER_LANGUAGE_MAP', '{}'))
    mapping.fetch(language.code, language.code)
  rescue JSON::ParserError
    raise TranslationProvider::PermanentError, 'Invalid TRANSLATION_PROVIDER_LANGUAGE_MAP JSON'
  end

  def non_translatable?(value)
    value.blank? ||
      value.match?(/Ad+(?:.d+)?z/) ||
      value.match?(/A(?:true|false|null)z/i) ||
      value.match?(%r{A(?:https?://|mailto:)}) ||
      value.match?(/A[a-f0-9]{32,}z/i)
  end

  def placeholders_valid?(source, target)
    source.scan(PLACEHOLDER_PATTERN).sort == target.scan(PLACEHOLDER_PATTERN).sort
  end

  def reload_i18n_backend!
    return unless I18n.backend.respond_to?(:backends)

    I18n.backend.backends.each do |backend|
      backend.reload! if backend.respond_to?(:reload!)
    end
  end

  def notify_generation(action)
    return unless @generation.actor

    TranslationGenerationNotification
      .with(action: action, user: @generation.actor)
      .deliver(@generation.actor, enqueue_job: false)

    @generation.actor.broadcast_notifications_refresh
  end
end
