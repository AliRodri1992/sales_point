# frozen_string_literal: true

module DemoRequests
  class FormComponent < ViewComponent::Base
    THEMES = [
      %w[emerald #059669 #0d9488], %w[sapphire #1e40af #1d4ed8], %w[sky #0284c7 #0369a1],
      %w[lime #84cc16 #65a30d], %w[olive #556b2f #3f5115], %w[yellow #fbc02d #f9a825],
      %w[gold #d4af37 #aa820a], %w[orange #f97316 #ea580c], %w[magenta #e21a84 #e21a84],
      %w[rose #fbcfe8 #f48fb1], %w[mint #a7f3d0 #34d399], %w[cherry #db2777 #be185d],
      %w[violet #7c3aed #6d28d9], %w[teal #0d9488 #0f766e], %w[indigo #4f46e5 #4338ca],
      %w[cyan #06b6d4 #0891b2], %w[fuchsia #d946ef #c026d3], %w[ruby #dc2626 #b91c1c],
      %w[bronze #854d0e #713f12], %w[slate #475569 #334155]
    ].freeze

    def initialize(demo_request:, notice: nil)
      super()
      @demo_request = demo_request
      @notice = notice
    end

    private

    attr_reader :demo_request, :notice

    def field_classes(attribute)
      class_names('demo-request__input', 'demo-request__input--invalid': demo_request.errors[attribute].any?)
    end

    def demo_field_label(attribute)
      return t('demo_requests.form.consent') if attribute == :terms_accepted
      return DemoRequest.human_attribute_name(:message) if attribute == :message

      t("demo_requests.new.#{attribute}")
    end

    def formatted_error(attribute, message)
      text = "#{demo_field_label(attribute)} #{message}".strip
      text.match?(/[.!?。？！]\z/) ? text : "#{text}."
    end

    def error_for(attribute)
      demo_request.errors[attribute].map { |message| formatted_error(attribute, message) }.join(' ')
    end

    def limits_for(attribute)
      options = DemoRequest.validators_on(attribute).find { |validator| validator.kind == :length }&.options || {}
      { minlength: options[:in]&.begin || options[:minimum],
        maxlength: options[:in]&.end || options[:maximum] }.compact
    end

    def field_options(attribute, data: {})
      limits_for(attribute).merge(
        required: attribute != :message,
        aria: { describedby: "demo_request_#{attribute}_error", invalid: demo_request.errors[attribute].any? },
        data: validation_messages(attribute).merge(demo_field: attribute).merge(data)
      )
    end

    def validation_message(attribute, code, **)
      formatted_error(attribute, demo_request.errors.generate_message(attribute, code, **))
    end

    def invalid_message(attribute)
      return formatted_error(attribute, t('demo_requests.form.phone_invalid')) if attribute == :phone
      return formatted_error(attribute, t('demo_requests.form.email_invalid')) if attribute == :email

      validation_message(attribute, :invalid)
    end

    def validation_messages(attribute)
      messages = { demo_required: validation_message(attribute, :blank), demo_invalid: invalid_message(attribute),
                   demo_accepted: validation_message(attribute, :accepted) }
      if attribute == :phone
        messages[:demo_pending] = formatted_error(attribute, t('demo_requests.form.phone_pending'))
        messages[:demo_unavailable] = formatted_error(attribute, t('demo_requests.form.phone_unavailable'))
      end
      add_length_messages(messages, attribute)
      add_branch_messages(messages, attribute)
      messages
    end

    def add_length_messages(messages, attribute)
      limits = limits_for(attribute)
      if limits[:minlength]
        messages[:demo_too_short] = validation_message(attribute, :too_short, count: limits[:minlength])
      end
      return unless limits[:maxlength]

      messages[:demo_too_long] = validation_message(attribute, :too_long, count: limits[:maxlength])
    end

    def add_branch_messages(messages, attribute)
      return unless attribute == :branches

      messages[:demo_integer] = validation_message(attribute, :not_an_integer)
      messages[:demo_minimum] = validation_message(attribute, :greater_than_or_equal_to, count: 1)
      messages[:demo_maximum] = validation_message(attribute, :less_than_or_equal_to, count: DemoRequest::MAX_BRANCHES)
    end
  end
end
