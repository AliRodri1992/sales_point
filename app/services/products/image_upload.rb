# frozen_string_literal: true

module Products
  class ImageUpload
    def self.valid?(file)
      return false unless file.respond_to?(:tempfile) && file.size.between?(1, ProductImageValidation::MAX_IMAGE_SIZE)

      actual_type = Marcel::MimeType.for(file.tempfile)
      ProductImageValidation::IMAGE_TYPES.include?(actual_type)
    end

    def self.call(file:, organization:, user:)
      raise ArgumentError unless valid?(file)

      metadata = { organization_id: organization.id, uploaded_by_id: user.id, purpose: 'product_image' }
      blob = ActiveStorage::Blob.create_and_upload!(io: file.tempfile, filename: file.original_filename, metadata:)
      PurgeUnusedImageJob.set(wait: 1.day).perform_later(blob.id)
      blob
    end

    def self.token(blob, organization:, user:)
      blob.signed_id(purpose: upload_purpose(organization, user), expires_in: 1.day)
    end

    def self.find_signed(token, organization:, user:)
      return unless organization && user

      ActiveStorage::Blob.find_signed(token, purpose: upload_purpose(organization, user))
    end

    def self.upload_purpose(organization, user)
      "product_image:#{organization.id}:#{user.id}"
    end
    private_class_method :upload_purpose
  end
end
