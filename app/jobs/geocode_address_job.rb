class GeocodeAddressJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Faraday::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on Faraday::ConnectionFailed, wait: :exponentially_longer, attempts: 5

  discard_on ActiveRecord::RecordNotFound
  discard_on StandardError do |_job, error|
    Rails.logger.error("[GeocodeAddressJob] Fatal: #{error.message}")
  end

  def perform(address_id, fingerprint = nil)
    AddressGeocodingService.new(address_id, fingerprint).call
  end
end
