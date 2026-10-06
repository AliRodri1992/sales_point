# frozen_string_literal: true

class DemoRequest < ApplicationRecord
  BUSINESS_TYPES = %w[grocery fashion restaurant pharmacy].freeze
  MAX_BRANCHES = 10_000

  belongs_to :assigned_to, class_name: 'User', optional: true

  attr_accessor :note

  has_many :activities, class_name: 'DemoRequestActivity', dependent: :destroy

  after_create :record_creation_activity
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

  before_validation :normalize_fields
  before_validation :record_terms_acceptance
  validate :validate_assigned_to

  validates :name, presence: true, length: { in: 2..100 }
  validates :email, presence: true, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone,
            presence: true,
            phone: {
              format: :e164,
              extensions: false,
              detailed_errors: true
            }
  validates :company, presence: true, length: { in: 2..150 }
  validates :business_type, presence: true, inclusion: { in: BUSINESS_TYPES }
  validates :branches, presence: true,
                       numericality: {
                         only_integer: true,
                         greater_than_or_equal_to: 1,
                         less_than_or_equal_to: MAX_BRANCHES
                       }
  validates :message, length: { maximum: 2_000 }, allow_blank: true
  validates :terms_accepted, acceptance: true
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validate :scheduled_at_required_for_scheduled_status
  validate :scheduled_at_must_be_future_when_scheduled

  private

  def normalize_fields
    self.name = normalize_text(name)
    self.company = normalize_text(company)
    self.email = email.to_s.strip.downcase.presence
    normalize_phone
  end

  def normalize_phone
    return if phone.blank?

    parsed_phone = Phonelib.parse(phone)
    self.phone = parsed_phone.e164 if parsed_phone.valid?
  end

  def validate_assigned_to
    return if assigned_to.blank?
    return if assigned_to.employee? && assigned_to.active?

    errors.add(:assigned_to, :invalid)
  end

  def record_terms_acceptance
    self.terms_accepted_at = terms_accepted ? (terms_accepted_at || Time.current) : nil
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

  def notify_demo_request
    notification = DemoRequestNotification.with(
      demo_request: self,
      locale: locale
    )
    notification.deliver(self)
  end
end
