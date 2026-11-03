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
    self.allowed_variables = value.to_s.split(',').map(&:strip).reject(&:blank?).uniq
  end
  validates :version_number, numericality: { only_integer: true, greater_than: 0 },
                             uniqueness: { scope: :email_template_id }
  validates :status, inclusion: { in: STATUSES }
  validates :subject, :html_body, :text_body, presence: true
  validate :variables_are_safe
  validate :declared_variables, if: -> { status == 'published' }
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
  end

  private

  def variables_are_safe
    return errors.add(:allowed_variables, :invalid) unless allowed_variables.is_a?(Array)

    allowed_variables.each do |variable|
      errors.add(:allowed_variables, :invalid) unless EmailTemplates::Renderer::KNOWN_VARIABLES.include?(variable)
    end
  end

  def declared_variables
    content = [subject, html_body, text_body].join(' ')
    used = content.scan(/\{\{([a-z][a-z0-9_]*)\}\}/).flatten.uniq
    errors.add(:allowed_variables, 'must include every placeholder') unless (used - allowed_variables).empty?
  end

  def protect_published_version
    throw :abort if status == 'published'
  end

  def published_version_is_immutable
    return unless status_was == 'published'
    return if changes.keys == ['updated_at']

    errors.add(:base, 'Published versions are immutable')
  end
end
