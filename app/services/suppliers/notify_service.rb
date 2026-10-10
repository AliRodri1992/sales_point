# frozen_string_literal: true

module Suppliers
  class NotifyService
    def self.call(action:, supplier:, user:)
      new.call(action:, supplier:, user:)
    end

    def call(action:, supplier:, user:)
      SupplierNotification
        .with(action: action, record: supplier, user: user)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end
  end
end
