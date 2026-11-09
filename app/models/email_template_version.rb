# frozen_string_literal: true

class EmailTemplateVersion < ApplicationRecord
  belongs_to :email_template
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :published_by, class_name: 'User', optional: true

  STATUSES = %w[draft published archived].freeze

  def allowed_variables_csv
    allowed_variables.join(', ')
  end

  def allowed_variables_csv=(value)
    self.allowed_variables = value.to_s.split(',').map(&:strip).compact_blank.uniq
  end
  validates :version_number, numericality: { only_integer: true, greater_than: 0 },
                             uniqueness: { scope: :email_template_id }
  validates :status, inclusion: { in: STATUSES }
  validates :subject, :html_body, :text_body, presence: true
  validates :subject, :preheader, length: { maximum: 250 }
  validates :allowed_variables, length: { maximum: 50 }
  validates :html_body, length: { maximum: 300_000 }
  validates :text_body, length: { maximum: 100_000 }
  validate :variables_are_safe
  validate :declared_variables
  validate :single_line_header_fields
  validate :sensitive_header_variables
  validates_with EmailTemplates::DeliveryReadiness, if: -> { status == 'published' && Rails.env.production? }
  validate :only_one_draft_per_template, if: -> { status == 'draft' && email_template_id.present? }
  validate :required_customization_variables, if: -> { status == 'published' }
  validate :published_version_is_immutable, on: :update
  before_destroy :protect_published_version

  def publish!(actor:)
    template = email_template
    template.with_lock do
      # Serialize competing publish requests and recheck the database state under
      # the template lock. The second request must not publish/audit twice.
      reload
      raise ActiveRecord::StaleObjectError.new(self, 'publish') unless status == 'draft'

      update!(status: 'published', published_by: actor, published_at: Time.current)
      template.update!(
        published_version: self, status: 'published', enabled: true,
        version: version_number, subject:, html_body:, text_body:, updated_by: actor
      )
    end
  rescue ActiveRecord::RecordInvalid
    # Keep the editable draft and its field errors after a failed publish attempt.
    self.status = 'draft'
    self.published_by = nil
    self.published_at = nil
    raise
  end

  private

  def single_line_header_fields
    %i[subject preheader].each do |attribute|
      errors.add(attribute, :invalid) if public_send(attribute).to_s.match?(/[\r\n]/)
    end
  end

  def sensitive_header_variables
    message = I18n.t('admin.email_templates.sensitive_header_variable')
    %i[subject preheader].each do |attribute|
      errors.add(attribute, message) if EmailTemplates::Renderer.sensitive_header?(public_send(attribute))
    end
  end

  def only_one_draft_per_template
    errors.add(:status, :taken) if self.class.where(email_template_id:, status: 'draft').where.not(id: id).exists?
  end

  def variables_are_safe
    return errors.add(:allowed_variables, :invalid) unless allowed_variables.is_a?(Array)

    return if allowed_variables.all? { |variable| EmailTemplates::Renderer::KNOWN_VARIABLES.include?(variable) }

    errors.add(:allowed_variables, :invalid)
  end

  def declared_variables
    validate_placeholder_syntax
    return unless allowed_variables.is_a?(Array) && errors[:allowed_variables].empty?

    errors.add(:allowed_variables, :undeclared_placeholders) unless (used_variables - allowed_variables).empty?
  end

  def validate_placeholder_syntax
    %i[subject preheader html_body text_body].each do |field|
      errors.add(field, :invalid) if EmailTemplates::Renderer.malformed_variables?(public_send(field))
    end
  end

  def used_variables
    %i[subject preheader html_body text_body].flat_map do |field|
      public_send(field).to_s.scan(EmailTemplates::Renderer::VARIABLE_PATTERN).flatten
    end.uniq
  end

  def required_customization_variables
    required = EmailTemplate::REQUIRED_CUSTOMIZATION_VARIABLES.fetch(email_template.key, [])
    required.each { |variable| validate_required_security_variable(variable) }
  end

  def validate_required_security_variable(variable)
    token = "{{#{variable}}}"
    message = I18n.t('admin.email_templates.required_customization_variable', variable:)
    declared = allowed_variables.is_a?(Array) && allowed_variables.include?(variable)
    errors.add(:allowed_variables, message) unless declared
    errors.add(:html_body, message) unless actionable_security_link?(token)
    errors.add(:text_body, message) unless text_body.to_s.include?(token)
  end

  def actionable_security_link?(token)
    markup = Nokogiri::HTML.fragment(html_body.to_s)
    valid_source = markup.css('a[href]').any? do |link|
      link['href'] == token && visible_security_link?(link)
    end
    return false unless valid_source

    # Use the exact same HTML sanitization as the outgoing email. Never contact
    # a provider or inspect real recipient-specific recovery/activation tokens.
    sample_url = 'https://delta.test/security-link-validation'
    sanitized = EmailTemplates::Renderer.sanitize_html(html_body.to_s.gsub(token, sample_url))
    Nokogiri::HTML.fragment(sanitized).css('a[href]').any? do |link|
      link['href'] == sample_url && visible_security_link?(link)
    end
  end

  def visible_security_link?(link)
    EmailTemplates::SecurityLinkVisibility.visible?(link)
  end

  def protect_published_version
    throw :abort if status == 'published'
  end

  def published_version_is_immutable
    return unless status_was == 'published'
    return if changes.keys == ['updated_at']

    errors.add(:base, :published_immutable)
  end
end
