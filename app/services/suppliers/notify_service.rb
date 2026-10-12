# frozen_string_literal: true

module Suppliers
  class NotifyService
    def self.call(action:, supplier:, user:, subject: supplier)
      new.call(action:, supplier:, user:, subject:)
    end

    def call(action:, supplier:, user:, subject:)
      key = event_key(action:, supplier:, user:, subject:)
      delivered = false

      ActiveRecord::Base.transaction do
        receipt = SupplierEventDelivery.create_or_find_by!(event_key: key) do |record|
          record.supplier = supplier
          record.recipient = user
        end
        if receipt.previously_new_record?
          SupplierNotification
            .with(action:, record: supplier, user:)
            .deliver(user, enqueue_job: false)
          delivered = true
        end
      end

      user.broadcast_notifications_refresh if delivered
      delivered
    end

    private

    def event_key(action:, supplier:, user:, subject:)
      version = [subject.updated_at&.iso8601(6), subject.try(:deleted_at)&.iso8601(6)]
      Digest::SHA256.hexdigest(
        [supplier.id, user.id, subject.class.name, subject.id, action, *version].join(':')
      )
    end
  end
end
