# frozen_string_literal: true

module EmailTemplates
  class Renderer
    VARIABLE_PATTERN = /\{\{([a-z][a-z0-9_]*)\}\}/
    SENSITIVE_URL_VARIABLES = %w[activation_url recovery_url].freeze
    STANDARD_LOGO_TAG = /<img\b[^>]*\bsrc=(["'])\{\{platform_logo\}\}\1[^>]*>/i
    URL_VARIABLES = %w[activation_url recovery_url support_url privacy_url
                       logo_url organization_logo platform_logo].freeze
    KNOWN_VARIABLES = %w[
      name recipient_name recipient_email invited_name organization_name organization_logo
      platform_logo platform_name logo_url support_email support_url privacy_url
      current_year activation_url recovery_url expiration_hours status_label
      primary_color secondary_color button_color footer_text
    ].freeze

    def self.sensitive_header?(content)
      content.to_s.scan(VARIABLE_PATTERN).flatten.intersect?(SENSITIVE_URL_VARIABLES)
    end

    def self.malformed_variables?(content)
      remaining = content.to_s.gsub(VARIABLE_PATTERN, '')
      remaining.include?('{{') || remaining.include?('}}')
    end

    # Shared whitelist for both delivery and critical-link validation at publish time.
    def self.sanitize_html(content)
      ActionController::Base.helpers.sanitize(
        content,
        tags: %w[html head body meta table tr td th p a img div span h1 h2 h3 strong b em ul ol li br hr],
        attributes: %w[lang charset name content width height role cellpadding cellspacing
                       style bgcolor href src alt align]
      )
    end

    def initialize(source:, values:, preview: false)
      @source = source
      @values = values.symbolize_keys
      @preview = preview
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
      sanitized = self.class.sanitize_html(html)
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
        validate_support_email!(value) if key == 'support_email'
        mode == :html ? ERB::Util.html_escape(value.to_s) : value.to_s
      end
    end

    def validate_variables!(allowed)
      contents = [@source.subject, (@source.preheader if @source.respond_to?(:preheader)),
                  @source.html_body, @source.text_body]
      validate_header_placeholders!(contents)

      used = contents.flat_map { |body| body.to_s.scan(VARIABLE_PATTERN).flatten }.uniq
      raise ArgumentError, 'Unapproved email variables' unless (used - allowed).empty?
    end

    def validate_header_placeholders!(contents)
      if contents.any? { |body| self.class.malformed_variables?(body) }
        raise ArgumentError, 'Malformed email variable'
      end

      headers = [@source.subject, (@source.preheader if @source.respond_to?(:preheader))]
      return unless headers.any? { |header| self.class.sensitive_header?(header) }

      raise ArgumentError, 'Sensitive email URL in header'
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

    def validate_support_email!(value)
      address = value.to_s
      valid = address.match?(URI::MailTo::EMAIL_REGEXP)
      raise ArgumentError, 'Invalid support email' unless valid

      domain = address.split('@', 2).last
      raise ArgumentError, 'Unconfigured support email' if example_host?(domain)
    end

    def example_host?(host)
      return false unless Rails.env.production? && !@preview

      normalized = host.downcase
      %w[example.com example.org example.net].any? do |domain|
        normalized == domain || normalized.end_with?(".#{domain}")
      end
    end
  end
end
