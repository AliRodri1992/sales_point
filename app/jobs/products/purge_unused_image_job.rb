# frozen_string_literal: true

module Products
  class PurgeUnusedImageJob < ApplicationJob
    queue_as :default

    def perform(blob_id)
      blob = ActiveStorage::Blob.find_by(id: blob_id)
      return unless blob && blob.metadata['purpose'] == 'product_image'
      return if blob.created_at > 23.hours.ago || blob.attachments.exists?

      blob.purge
    end
  end
end
