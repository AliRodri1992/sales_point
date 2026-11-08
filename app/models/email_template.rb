# frozen_string_literal: true

class EmailTemplate < ApplicationRecord
  CRITICAL_GLOBAL_KEYS = %w[
    user_invitation user_invitation_resend user_welcome password_recovery
    password_changed account_suspended account_reactivated security_alert
    email_changed user_status_changed
  ].freeze
  REQUIRED_CUSTOMIZATION_VARIABLES = {
    'user_invitation' => %w[activation_url],
    'user_invitation_resend' => %w[activation_url],
    'password_recovery' => %w[recovery_url]
  }.freeze

  belongs_to :organization, optional: true
  belongs_to :source_template, class_name: 'EmailTemplate', inverse_of: :customizations, optional: true
  has_many :customizations, class_name: 'EmailTemplate', foreign_key: :source_template_id,
                            inverse_of: :source_template, dependent: :restrict_with_exception
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
  validates :name, length: { maximum: 150 }
  validates :key, length: { maximum: 100 }
  validates :category, length: { maximum: 100 }
  validates :key, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :key, uniqueness: { scope: %i[organization_id locale] }
  validates :subject, length: { maximum: 250 }
  validates :html_body, length: { maximum: 300_000 }
  validates :text_body, length: { maximum: 100_000 }
  validate :published_version_belongs_to_template
  validate :valid_customization_source
  validate :identity_immutable_after_publish, on: :update

  def protected_global?
    organization_id.nil? && CRITICAL_GLOBAL_KEYS.include?(key)
  end

  def customized?
    source_template_id.present?
  end

  def self.resolve(key:, locale:, organization: nil)
    requested = locale.to_s.in?(%w[es en ko]) ? locale.to_s : 'es'
    published.where(key:).find_by(organization:, locale: requested) ||
      published.global.find_by(key:, locale: requested) ||
      published.where(key:).find_by(organization:, locale: 'es') ||
      published.global.find_by(key:, locale: 'es')
  end

  def self.ensure_invitation_template!
    EmailTemplates::InvitationContent.ensure_published!
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
    default_locale = locale.in?(%w[es en ko]) ? locale : I18n.locale
    self.subject ||= I18n.t('admin.email_templates.default_subject', locale: default_locale)
    self.html_body ||= EmailTemplates::DraftStarter.html(default_locale)
    self.text_body ||= EmailTemplates::DraftStarter.plain(default_locale)
  end

  def new_draft!(actor:)
    with_lock do
      existing_draft = versions.where(status: 'draft').order(version_number: :desc).first
      return existing_draft if existing_draft

      source = published_version || versions.order(version_number: :desc).first
      versions.create!(
        version_number: versions.maximum(:version_number).to_i + 1,
        status: 'draft', created_by: actor, **draft_content(source)
      )
    end
  end

  def draft_content(source)
    title = source&.subject || subject
    body = source&.html_body || html_body
    plain = source&.text_body || text_body
    variables = source&.allowed_variables.presence ||
                [title, source&.preheader, body, plain].join(' ').scan(/\{\{([a-z][a-z0-9_]*)\}\}/).flatten.uniq
    { subject: title, preheader: source&.preheader.to_s, html_body: body, text_body: plain,
      allowed_variables: variables }
  end

  def audit!(action:, actor:, version: nil, metadata: {})
    audits.create!(action:, actor:, organization:, email_template_version: version, metadata:)
  end

  def render_with(values)
    source = published_version || self
    EmailTemplates::Renderer.new(source:, values:).render
  end

  private

  def valid_customization_source
    return unless source_template

    valid = organization_id.present? && source_template.organization_id.nil? &&
            source_template.key == key && source_template.locale == locale
    errors.add(:source_template, :invalid) unless valid
  end

  def identity_immutable_after_publish
    return unless published_version_id_was

    changed = will_save_change_to_key? || will_save_change_to_locale? ||
              will_save_change_to_organization_id? || will_save_change_to_source_template_id?
    errors.add(:base, :published_identity_immutable) if changed
  end

  def published_version_belongs_to_template
    return unless published_version
    return if published_version.email_template_id == id

    errors.add(:published_version, :invalid)
  end
end
