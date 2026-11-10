# frozen_string_literal: true

module Admin
  module ProductFormWriting
    TEMPORARY_ASSOCIATIONS = %i[product_variant product_presentation].freeze

    private

    def save_product
      attributes = product_params
      unless valid_image_assignment?(attributes)
        @product.assign_attributes(attributes.except(:image))
        return false
      end
      normalize_uploaded_image(attributes)
      writer = Products::SaveCatalogEntry.new(product: @product, actor: current_user, attributes:)
      saved = writer.call
      @price_change_pending = writer.pending
      saved
    end

    def product_update_message
      t(@price_change_pending ? 'admin.catalog_design.price_pending_notice' : 'admin.products.updated')
    end

    def normalize_uploaded_image(attributes)
      image = attributes[:image]
      return if image.blank?

      if image.is_a?(String)
        attributes[:image] = @verified_product_blob
        return
      end

      blob = Products::ImageUpload.call(file: image, organization: current_organization, user: current_user)
      attributes[:image] = blob.signed_id
    end

    def normalize_image_parameters(attributes)
      signed_id = attributes.delete(:image_signed_id)
      attributes[:image] = signed_id if attributes[:image].blank? && signed_id.present?
      image = attributes[:image]
      unchanged = image.is_a?(String) && @product.image.attached? && image == @product.image.blob.signed_id
      attributes.delete(:image) if image.blank? || unchanged
    end

    def normalize_temporary_option_ids(attributes)
      nested = attributes[:product_barcodes_attributes]
      return unless nested

      rows = nested.respond_to?(:each_pair) ? nested.values : nested
      rows.each do |row|
        TEMPORARY_ASSOCIATIONS.each do |association|
          id_field = :"#{association}_id"
          token = row[id_field].to_s
          next unless token.start_with?('new:')

          row[:"#{association}_client_key"] = token.delete_prefix('new:')
          row[id_field] = nil
        end
      end
    end

    def product_params
      params.expect(product: [
                      :code, :name, :description, :price, :cost, :barcode, :sku, :category_id,
                      :sat_unit_key_id, :sat_tax_id, :tracking_mode, :status, :image, :image_signed_id,
                      :position, :featured, :price_change_reason,
                      { product_variants_attributes: [%i[id name sku status size color model client_key]],
                        product_presentations_attributes: [%i[id name units status client_key]],
                        product_barcodes_attributes: [%i[id _destroy value symbology product_variant_id
                                                         product_presentation_id product_variant_client_key
                                                         product_presentation_client_key]] }
                    ]).tap do |attributes|
        normalize_image_parameters(attributes)
        normalize_temporary_option_ids(attributes)
      end
    end
  end
end
