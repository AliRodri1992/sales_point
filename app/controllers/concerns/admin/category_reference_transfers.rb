# frozen_string_literal: true

module Admin
  module CategoryReferenceTransfers
    def references
      prepare_reference_transfer
    end

    def reassign
      prepare_reference_transfer(params.expect(category_reference_transfer: [:target_category_id]))
      return render :references, status: :unprocessable_content unless @reference_transfer.save

      reference_transfer_saved
    end

    private

    def reference_transfer_saved
      load_categories
      broadcast_categories_update
      Turbo::StreamsChannel.broadcast_refresh_to("products_catalog_#{current_organization.id}")
      @swal_message = t('admin.categories.references.saved', name: @reference_transfer.target.name)
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html do
          redirect_to admin_categories_path(request.query_parameters), notice: @swal_message, status: :see_other
        end
      end
    end

    def prepare_reference_transfer(attributes = {})
      @reference_transfer = Categories::ReferenceTransfer.new(source: @category, **attributes.to_h.symbolize_keys)
      @reference_targets = scoped_categories.available.where.not(id: @category.id).order(:name, :id)
    end
  end
end
