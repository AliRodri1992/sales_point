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
  validate :only_one_draft_per_template, if: -> { status == 'draft' && email_template_id.present? }
  validate :required_customization_variables, if: -> { status == 'published' }
  validate :published_version_is_immutable, on: :update
  before_destroy :protect_published_version

  def publish!(actor:)
    raise ArgumentError, 'Only draft versions may be published' unless status == 'draft'

    email_template.with_lock do
      update!(status: 'published', published_by: actor, published_at: Time.current)
      email_template.update!(
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

  def only_one_draft_per_template
    other_drafts = self.class.where(email_template_id:, status: 'draft').where.not(id: id)
    errors.add(:status, :taken) if other_drafts.exists?
  end

  def variables_are_safe
    return errors.add(:allowed_variables, :invalid) unless allowed_variables.is_a?(Array)

    allowed_variables.each do |variable|
      errors.add(:allowed_variables, :invalid) unless EmailTemplates::Renderer::KNOWN_VARIABLES.include?(variable)
    end
  end

  def declared_variables
    return unless allowed_variables.is_a?(Array)

    content = [subject, preheader, html_body, text_body].join(' ')
    used = content.scan(/\{\{([a-z][a-z0-9_]*)\}\}/).flatten.uniq
    errors.add(:allowed_variables, :undeclared_placeholders) unless (used - allowed_variables).empty?
  end

  def required_customization_variables
    return if email_template.organization_id.nil?

    required = EmailTemplate::REQUIRED_CUSTOMIZATION_VARIABLES.fetch(email_template.key, [])
    required.each { |variable| validate_required_security_variable(variable) }
  end

  def validate_required_security_variable(variable)
    token = "{{#{variable}}}"
    message = I18n.t('admin.email_templates.required_customization_variable', variable:)
    declared = allowed_variables.is_a?(Array) && allowed_variables.include?(variable)
    errors.add(:allowed_variables, message) unless declared
    errors.add(:html_body, message) unless html_body.to_s.include?(token)
    errors.add(:text_body, message) unless text_body.to_s.include?(token)
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
