# frozen_string_literal: true

module Suppliers
  class NotifyService
    def self.call(action:, supplier:, user:, subject: supplier, event_token: nil)
      new.call(action:, supplier:, user:, subject:, event_token:)
    end

    def call(action:, supplier:, user:, subject:, event_token:)
      key = event_key(action:, supplier:, user:, subject:, event_token:)
      delivered = deliver_once(key:, action:, supplier:, user:)
      user.broadcast_notifications_refresh if delivered
      delivered
    end

    private

    def deliver_once(key:, action:, supplier:, user:)
      delivered = false
      ActiveRecord::Base.transaction do
        receipt = SupplierEventDelivery.create_or_find_by!(event_key: key) do |record|
          record.supplier = supplier
          record.recipient = user
        end
        if receipt.previously_new_record?
          SupplierNotification.with(action:, record: supplier, user:)
                              .deliver(user, enqueue_job: false)
          delivered = true
        end
      end
      delivered
    end

    def event_key(action:, supplier:, user:, subject:, event_token:)
      version = [subject.try(:updated_at)&.iso8601(6), subject.try(:deleted_at)&.iso8601(6)]
      Digest::SHA256.hexdigest(
        [supplier.id, user.id, subject.class.name, subject.id, action, event_token, *version].join(':')
      )
    end
  end
end
