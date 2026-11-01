# frozen_string_literal: true

# Prevent delivery of stale messages for soft-deleted demo requests.
# ActiveJob can deserialize a historical record even after it was archived.
module DemoRequestDeliveryGuard
  extend ActiveSupport::Concern

  included do
    after_action :suppress_deleted_demo_request_delivery
  end

  private

  def suppress_deleted_demo_request_delivery
    demo_request = params[:demo_request]
    return unless demo_request.is_a?(DemoRequest)
    return if demo_request.available_for_notification?

    mail.perform_deliveries = false
    Rails.logger.info('[DemoRequestMailer] Skipped email: demo request was archived')
  end
end
