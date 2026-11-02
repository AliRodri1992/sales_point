# frozen_string_literal: true

module Admin
  module OnboardingHelper
    STEP_SECTIONS = { 1 => %i[company fiscal], 2 => [:branches], 3 => [:terminals], 4 => [:payments] }.freeze
    SECTION_STEPS = { company: 1, fiscal: 1, branches: 2, terminals: 3, payments: 4, migration: 5, team: 5 }.freeze

    def onboarding_step_complete?(step, progress)
      sections = progress[:sections].reject { |item| item[:status] == 'not_applicable' }
      keys = STEP_SECTIONS[step]
      sections = sections.select { |item| keys.include?(item[:key]) } if keys
      sections.all? { |item| item[:percentage] == 100 }
    end

    def onboarding_section_path(key)
      admin_onboarding_path(step: SECTION_STEPS.fetch(key), anchor: key == :team ? 'onboarding-team' : nil)
    end

    def onboarding_messages(record, attribute, label: nil)
      details = record.errors.details[attribute]
      messages = record.errors[attribute]
      messages = messages.zip(details).filter_map { |message, error| message if error[:error] == :blank } if
        details.any? { |error| error[:error] == :blank }
      label ||= record.class.human_attribute_name(attribute)
      messages.map { |message| onboarding_message(label, message) }
    end

    def onboarding_message(label, message)
      text = "#{label} #{message}".strip
      text.match?(/[.!?。？！]\z/) ? text : "#{text}."
    end

    def onboarding_limits(record, attribute)
      options = record.class.validators_on(attribute).find { |validator| validator.kind == :length }&.options || {}
      { minlength: options[:in]&.begin || options[:minimum],
        maxlength: options[:in]&.end || options[:maximum] }.compact
    end

    def onboarding_field_options(form, attribute, label:, required: true, error_attribute: attribute)
      record = form.object
      id = form.field_id(attribute)
      invalid = record.errors[error_attribute].any?
      limits = onboarding_limits(record, attribute)
      data = onboarding_validation_data(record, error_attribute, label, limits)
      limits.merge(id:, required:, class: 'onboarding-input',
                   aria: { invalid:, describedby: "#{id}_error" }, data:)
    end

    def onboarding_validation_data(record, attribute, label, limits)
      data = { onboarding_field: true, label:,
               blank: onboarding_message(label, record.errors.generate_message(attribute, :blank)),
               invalid: onboarding_message(label, record.errors.generate_message(attribute, :invalid)) }
      data[:too_short] = onboarding_length_message(record, attribute, label, :too_short, limits[:minlength])
      data[:too_long] = onboarding_length_message(record, attribute, label, :too_long, limits[:maxlength])
      data
    end

    def onboarding_length_message(record, attribute, label, type, count)
      return unless count

      onboarding_message(label, record.errors.generate_message(attribute, type, count:))
    end

    def onboarding_countries
      Country.active.ordered.map do |country|
        rules = Addresses::CountryRules.new(country.iso_alpha2)
        pattern = Addresses::CountryRules::POSTAL_FORMATS.fetch(country.iso_alpha2,
                                                                Addresses::CountryRules::DEFAULT_POSTAL_FORMAT)
        [country.localized_name, country.id, { data: { country_code: country.iso_alpha2,
                                                       required_fields: rules.required_fields.join(','),
                                                       postal_pattern: onboarding_pattern(pattern) } }]
      end
    end

    def onboarding_pattern(regexp)
      regexp.source.sub('\\A', '^').sub('\\z', '$')
    end

    def onboarding_current_title(step)
      step == 5 ? t('admin.onboarding_ui.review_title') : t("admin.onboarding.steps.#{step}.heading")
    end
  end
end
