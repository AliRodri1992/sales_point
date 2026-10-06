# frozen_string_literal: true

class DemoRequest < ApplicationRecord
  BUSINESS_TYPES = %w[grocery fashion restaurant pharmacy].freeze
  MAX_BRANCHES = 10_000

  belongs_to :assigned_to, class_name: 'User', optional: true

  has_many :activities, class_name: 'DemoRequestActivity', dependent: :destroy

  after_create_commit :notify_demo_request
  after_create_commit :record_creation_activity

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

  def record_terms_acceptance
    self.terms_accepted_at = terms_accepted ? (terms_accepted_at || Time.current) : nil
  end

  def normalize_text(value)
    value.to_s.strip.gsub(/\s+/, ' ').presence
  end

  def record_creation_activity
    activities.create!(action: 'created')
  end

  def notify_demo_request
    notification = DemoRequestNotification.with(
      demo_request: self,
      locale: I18n.locale.to_s
    )
    notification.deliver(self)
  end
end
