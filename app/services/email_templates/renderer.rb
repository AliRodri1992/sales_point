# frozen_string_literal: true

module EmailTemplates
  class Renderer
    VARIABLE_PATTERN = /\{\{([a-z][a-z0-9_]*)\}\}/
    URL_VARIABLES = %w[activation_url support_url privacy_url logo_url organization_logo platform_logo].freeze
    KNOWN_VARIABLES = %w[
      recipient_name recipient_email invited_name organization_name organization_logo
      platform_logo platform_name logo_url support_email support_url privacy_url
      current_year activation_url expiration_hours status_label
    ].freeze

    def initialize(source:, values:)
      @source = source
      @values = values.symbolize_keys
    end

    def render
      allowed = @source.respond_to?(:allowed_variables) ? @source.allowed_variables : []
      allowed = allowed.map(&:to_s)
      validate_variables!(allowed.presence || KNOWN_VARIABLES)
      [render_subject, render_html, render_plain]
    end

    private

    def render_subject
      replace(@source.subject, :plain).gsub(/[\r\n]/, ' ')
    end

    def render_html
      html = replace(@source.html_body, :html)
      ActionController::Base.helpers.sanitize(
        html,
        tags: %w[html head body meta table tr td th p a img div span h1 h2 h3 strong b em ul ol li br hr],
        attributes: %w[lang charset name content width height role cellpadding cellspacing style href src alt align]
      )
    end

    def render_plain
      replace(@source.text_body, :plain)
    end

    def replace(source, mode)
      source.to_s.gsub(VARIABLE_PATTERN) do
        key = Regexp.last_match(1)
        value = @values.fetch(key.to_sym) { raise ArgumentError, "Missing email variable: #{key}" }
        validate_url!(key, value) if URL_VARIABLES.include?(key)
        mode == :html ? ERB::Util.html_escape(value.to_s) : value.to_s
      end
    end

    def validate_variables!(allowed)
      used = [@source.subject, @source.html_body, @source.text_body].flat_map do |body|
        body.to_s.scan(VARIABLE_PATTERN).flatten
      end.uniq
      raise ArgumentError, 'Unapproved email variables' unless (used - allowed).empty?
    end

    def validate_url!(key, value)
      parsed = URI.parse(value.to_s)
      raise ArgumentError, "Unsafe email URL: #{key}" unless parsed.is_a?(URI::HTTPS) ||
                                                               (Rails.env.development? && parsed.is_a?(URI::HTTP))
    rescue URI::InvalidURIError
      raise ArgumentError, "Invalid email URL: #{key}"
    end
  end
end
