# frozen_string_literal: true

module ProductImageValidation
  extend ActiveSupport::Concern

  IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  included do
    validate :valid_product_image
  end

  private

  def valid_product_image
    return unless image.attached? && (new_record? || attachment_changes.key?('image'))

    unless IMAGE_TYPES.include?(image.blob.content_type)
      errors.add(:image,
                 I18n.t('admin.catalog_design.image_type_error'))
    end
    return if image.blob.byte_size <= MAX_IMAGE_SIZE

    errors.add(:image, I18n.t('admin.catalog_design.image_size_error'))
  end
end
