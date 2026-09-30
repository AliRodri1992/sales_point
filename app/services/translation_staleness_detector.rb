# frozen_string_literal: true

require 'digest'

class TranslationStalenessDetector
  def self.call(language, catalog)
    language.translates.find_each do |translation|
      source_text = catalog[translation.key]
      next unless source_text.is_a?(String)

      digest = Digest::SHA256.hexdigest(source_text)

      if translation.source_text_digest.blank?
        translation.update_columns(
          source_text_when_translated: source_text,
          source_text_digest: digest
        )
      elsif translation.source_text_digest != digest
        translation.update_columns(stale_at: Time.current) unless translation.stale?
      elsif translation.stale?
        translation.update_columns(stale_at: nil)
      end
    end
  end
end
