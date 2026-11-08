# frozen_string_literal: true

module EmailTemplates
  class Renderer
    VARIABLE_PATTERN = /\{\{([a-z][a-z0-9_]*)\}\}/
    STANDARD_LOGO_TAG = /<img\b[^>]*\bsrc=(["'])\{\{platform_logo\}\}\1[^>]*>/i
    URL_VARIABLES = %w[activation_url recovery_url support_url privacy_url
                       logo_url organization_logo platform_logo].freeze
    KNOWN_VARIABLES = %w[
      name recipient_name recipient_email invited_name organization_name organization_logo
      platform_logo platform_name logo_url support_email support_url privacy_url
      current_year activation_url recovery_url expiration_hours status_label
      primary_color secondary_color button_color footer_text
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
      html = replace(enlarge_standard_logo(@source.html_body), :html)
      sanitized = ActionController::Base.helpers.sanitize(
        html,
        tags: %w[html head body meta table tr td th p a img div span h1 h2 h3 strong b em ul ol li br hr],
        attributes: %w[lang charset name content width height role cellpadding cellspacing
                       style bgcolor href src alt align]
      )
      inject_preheader(sanitized)
    end

    # Adapt legacy stock logo markup without editing immutable published versions.
    def enlarge_standard_logo(html)
      html.to_s.gsub(STANDARD_LOGO_TAG) do |tag|
        tag.gsub(/\bwidth=(["'])(?:210|214|220|222|244)\1/, 'width="320"')
           .gsub(/(?<![-\w])width:\s*(?:210|214|220|222|244)px\b/, 'width:320px')
      end
    end

    def inject_preheader(html)
      return html unless @source.respond_to?(:preheader) && @source.preheader.present?

      content = ERB::Util.html_escape(replace(@source.preheader, :plain))
      hidden = %(<div style="display:none!important;max-height:0;overflow:hidden;opacity:0;">#{content}</div>)
      return html.sub(/<body\b[^>]*>/i) { |match| "#{match}#{hidden}" } if html.match?(/<body\b/i)

      "#{hidden}#{html}"
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
      used = [@source.subject, (@source.preheader if @source.respond_to?(:preheader)),
              @source.html_body, @source.text_body].flat_map do |body|
        body.to_s.scan(VARIABLE_PATTERN).flatten
      end.uniq
      raise ArgumentError, 'Unapproved email variables' unless (used - allowed).empty?
    end

    def validate_url!(key, value)
      parsed = URI.parse(value.to_s)
      valid_scheme = parsed.is_a?(URI::HTTPS) || (Rails.env.development? && parsed.is_a?(URI::HTTP))
      valid = valid_scheme && parsed.host.present? && parsed.userinfo.nil?
      raise ArgumentError, "Unsafe email URL: #{key}" unless valid

      raise ArgumentError, "Unconfigured email URL: #{key}" if example_host?(parsed.host)
    rescue URI::InvalidURIError
      raise ArgumentError, "Invalid email URL: #{key}"
    end

    def example_host?(host)
      return false unless Rails.env.production?

      normalized = host.downcase
      %w[example.com example.org example.net].any? do |domain|
        normalized == domain || normalized.end_with?(".#{domain}")
      end
    end
  end
end
