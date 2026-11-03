# frozen_string_literal: true

class EmailTemplate < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  belongs_to :published_version, class_name: 'EmailTemplateVersion', optional: true
  has_many :versions, class_name: 'EmailTemplateVersion', dependent: :restrict_with_exception
  has_many :audits, class_name: 'EmailTemplateAudit', dependent: :restrict_with_exception

  STATUSES = %w[draft published inactive archived].freeze
  scope :global, -> { where(organization_id: nil) }
  scope :published, -> { where(status: 'published', enabled: true, deleted_at: nil) }
  scope :visible_to, ->(organization) { where(organization_id: [nil, organization&.id]) }

  validates :key, :locale, :name, :category, :subject, :html_body, :text_body, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :locale, inclusion: { in: %w[es en ko] }
  validates :key, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :key, uniqueness: { scope: %i[organization_id locale] }
  validate :published_version_belongs_to_template

  def self.resolve(key:, locale:, organization: nil)
    requested = locale.to_s.in?(%w[es en ko]) ? locale.to_s : 'es'
    published.where(key:).find_by(organization:, locale: requested) ||
      published.global.find_by(key:, locale: requested) ||
      published.global.find_by(key:, locale: 'es')
  end

  def self.ensure_invitation_template!
    return if global.exists?(key: 'user_invitation', locale: 'es')

    load Rails.root.join('db/seeds/email_templates.rb')
  end

  def self.ensure_status_template!
    return if global.exists?(key: 'user_status_changed', locale: 'es')

    load Rails.root.join('db/seeds/user_status_templates.rb')
  end

  def prepare_for_creation!(actor:, organization:, global: false)
    self.organization = global ? nil : organization
    self.created_by = actor
    self.updated_by = actor
    self.status = 'draft'
    self.enabled = false
    self.subject ||= 'New template'
    self.html_body ||= '<p>{{recipient_name}}</p>'
    self.text_body ||= '{{recipient_name}}'
  end

  def new_draft!(actor:)
    with_lock do
      next_number = versions.maximum(:version_number).to_i + 1
      source = published_version || versions.order(version_number: :desc).first
      versions.create!(
        version_number: next_number, status: 'draft', created_by: actor,
        subject: source&.subject || subject, html_body: source&.html_body || html_body,
        text_body: source&.text_body || text_body,
        allowed_variables: source&.allowed_variables || []
      )
    end
  end

  def audit!(action:, actor:, version: nil)
    audits.create!(action:, actor:, organization:, email_template_version: version)
  end

  def render_with(values)
    source = published_version || self
    EmailTemplates::Renderer.new(source:, values:).render
  end

  private

  def published_version_belongs_to_template
    return unless published_version
    return if published_version.email_template_id == id

    errors.add(:published_version, :invalid)
  end
end
