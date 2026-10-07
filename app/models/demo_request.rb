# frozen_string_literal: true

class DemoRequest < ApplicationRecord
  BUSINESS_TYPES = %w[grocery fashion restaurant pharmacy].freeze
  CONTACT_CHANNELS = %w[call whatsapp email other].freeze
  CONTACT_OUTCOMES = %w[interested needs_information wants_demo no_answer not_interested].freeze
  DEMO_OUTCOMES = %w[very_interested interested needs_follow_up not_interested no_show].freeze
  MAX_BRANCHES = 10_000

  belongs_to :assigned_to, class_name: 'User', optional: true

  attr_accessor :note

  has_many :activities, class_name: 'DemoRequestActivity', dependent: :destroy

  before_validation :normalize_fields
  before_validation :record_terms_acceptance
  before_validation :set_commercial_timestamps
  after_create :record_creation_activity
  after_update :record_note_activity
  after_create_commit :notify_demo_request

  enum :status,
       {
         pending: 'pending',
         contacted: 'contacted',
         scheduled: 'scheduled',
         completed: 'completed',
         converted: 'converted',
         cancelled: 'cancelled'
       },
       default: :pending,
       validate: true

  validate :validate_assigned_to
  validate :validate_commercial_follow_up
  validate :scheduled_at_required_for_scheduled_status
  validate :scheduled_at_must_be_future_when_scheduled

  validates :name, presence: true, length: { in: 2..100 }
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true,
                    format: { with: /\A\+/, message: :phone_e164_format },
                    phone: { format: :e164, extensions: false, detailed_errors: true }
  validates :company, presence: true, length: { in: 2..150 }
  validates :business_type, presence: true, inclusion: { in: BUSINESS_TYPES }
  validates :branches, presence: true,
                       numericality: { only_integer: true,
                                       greater_than_or_equal_to: 1,
                                       less_than_or_equal_to: MAX_BRANCHES }
  validates :message, length: { maximum: 2_000 }, allow_blank: true
  validates :terms_accepted, acceptance: true
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :note, length: { maximum: 2_000 }, allow_blank: true
  validates :contact_channel, inclusion: { in: CONTACT_CHANNELS }, allow_blank: true
  validates :contact_outcome, inclusion: { in: CONTACT_OUTCOMES }, allow_blank: true
  validates :demo_outcome, inclusion: { in: DEMO_OUTCOMES }, allow_blank: true
  validates :next_action, length: { maximum: 120 }, allow_blank: true

  def follow_up_due?
    next_follow_up_at.present? && next_follow_up_at <= Time.current
  end

  def self.workflow_handler(demo_request:, current_user:, previous_status:, previous_assignee:)
    DemoRequests::Workflow.new(demo_request, current_user, previous_status, previous_assignee).call
  end

  private

  def normalize_fields
    self.name = normalize_text(name)
    self.company = normalize_text(company)
    self.email = email.to_s.strip.downcase.presence
    self.next_action = normalize_text(next_action)
    normalize_phone
  end

  def normalize_phone
    return if phone.blank?

    # Don't normalize if there's an extension (semicolon)
    return if phone.to_s.include?(';')

    # Extract just the digits and optional + prefix
    cleaned = phone.to_s.strip.gsub(/\s+/, '')

    # If it starts with +, normalize to E.164 format
    return unless cleaned.start_with?('+')

    parsed_phone = Phonelib.parse(cleaned)
    self.phone = parsed_phone.e164 if parsed_phone.possible?
  end

  def validate_assigned_to
    return if assigned_to.blank?
    return if assigned_to.employee? && assigned_to.active?

    errors.add(:assigned_to, :invalid)
  end

  def record_terms_acceptance
    self.terms_accepted_at = terms_accepted ? (terms_accepted_at || Time.current) : nil
  end

  def set_commercial_timestamps
    self.contacted_at ||= Time.current if contacted? && will_save_change_to_status?
    self.converted_at ||= Time.current if converted? && will_save_change_to_status?
  end

  def validate_commercial_follow_up
    DemoRequests::Validations.validate_commercial_follow_up(self)
  end

  def normalize_text(value)
    value.to_s.strip.gsub(/\s+/, ' ').presence
  end

  def scheduled_at_required_for_scheduled_status
    return unless scheduled?
    return if scheduled_at.present?

    errors.add(:scheduled_at, :blank)
  end

  def scheduled_at_must_be_future_when_scheduled
    return unless scheduled? && scheduled_at.present?
    return if scheduled_at > Time.current

    errors.add(:scheduled_at, :in_future)
  end

  def record_creation_activity
    activities.create!(action: 'created')
  end

  def record_note_activity
    activities.create!(action: 'note_added', details: note) if note.present?
  end

  def notify_demo_request
    DemoRequestNotification.with(demo_request: self, locale: locale).deliver(self)
  end
end
