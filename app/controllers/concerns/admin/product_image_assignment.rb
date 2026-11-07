# frozen_string_literal: true

module Admin
  module ProductImageAssignment
    private

    def valid_image_assignment?(attributes)
      image = attributes[:image]
      return true if image.blank?
      return reject_product_image? unless image.is_a?(String) || Products::ImageUpload.valid?(image)
      return true unless image.is_a?(String)

      @verified_product_blob = Products::ImageUpload.find_signed(image, organization: current_organization,
                                                                        user: current_user)
      return true if @verified_product_blob && permitted_product_blob?(@verified_product_blob)

      reject_product_image?
    end

    def permitted_product_blob?(blob)
      return true if @product.image.attached? && @product.image.blob_id == blob.id

      metadata = blob.metadata
      metadata['organization_id'] == current_organization&.id && metadata['uploaded_by_id'] == current_user.id &&
        metadata['purpose'] == 'product_image'
    end

    def reject_product_image?
      @product.errors.add(:image, t('admin.catalog_design.image_upload_error'))
      false
    end
  end
end
