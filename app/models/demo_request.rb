# frozen_string_literal: true

class DemoRequest < ApplicationRecord
  after_create_commit :notify_demo_request

  enum :status,
       {
         pending: 'pending',
         contacted: 'contacted',
         completed: 'completed'
       },
       default: :pending,
       validate: true

  validates :name,
            presence: true,
            length: { in: 2..100 }

  validates :email,
            presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            length: { maximum: 255 },
            allow_blank: false

  validates :company,
            presence: true,
            length: { in: 2..150 }

  validates :phone,
            presence: true,
            format: { with: /\A[0-9+\-\s()]{7,20}\z/ },
            length: { in: 7..20 }

  validates :message,
            length: { maximum: 2_000 },
            allow_blank: true

  private

  def notify_demo_request
    notification = DemoRequestNotification.with(
      demo_request: self,
      locale: I18n.locale.to_s
    )
    notification.deliver(self)
  end
end
