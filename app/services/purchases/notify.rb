# frozen_string_literal: true

module Purchases
  class Notify
    def self.call(record:, action:, user:)
      key = Digest::SHA256.hexdigest([record.class.name, record.id, action, user.id].join(':'))
      delivered = false

      ActiveRecord::Base.transaction do
        receipt = PurchaseEventDelivery.create_or_find_by!(event_key: key) do |row|
          row.organization = record.organization
          row.recipient = user
        end
        if receipt.previously_new_record?
          PurchaseNotification.with(action:, record:, user:)
                              .deliver(user, enqueue_job: false)
          delivered = true
        end
      end

      user.broadcast_notifications_refresh if delivered
      delivered
    end
  end
end
