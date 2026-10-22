# frozen_string_literal: true

module SupplierDocumentManagement
  private

  def persist_uploaded_documents(supplier, files)
    supplier.documents.attach(files)
    ActiveStorage::Attachment.where(record: supplier, name: 'documents')
                             .order(id: :desc).limit(files.size).each do |attachment|
      supplier.supplier_documents.create!(attachment:, uploaded_by: current_user, **metadata_attributes)
    end
  end

    def replace_document(supplier, document)
      return reject_file(supplier) unless valid_file?(document_file)

      supplier.with_lock do
        supplier.documents.attach(document_file)
        attachment = ActiveStorage::Attachment.where(record: supplier, name: 'documents').order(:id).last
        document.update!(current_version: false, updated_by: current_user)
        supplier.supplier_documents.create!(
          attachment:, uploaded_by: current_user, previous_version: document,
          series_id: document.series_id, version: document.version + 1, **metadata_attributes(document)
        )
      end
      redirect_documents(supplier, :replaced)
    end

    def current_document(supplier)
      SupplierDocument.import_existing!(supplier)
      supplier.supplier_documents.visible.find_by!(attachment_id: params[:document_id])
    end

    def document_for(supplier)
      SupplierDocument.import_existing!(supplier)
      supplier.supplier_documents.find_by!(attachment_id: params[:document_id])
    end

    def metadata_attributes(previous = nil)
      data = document_params
      {
        category: allowed_value(data[:category], previous&.category, SupplierDocument::CATEGORIES, 'other'),
        status: allowed_value(data[:status], previous&.status, SupplierDocument::STATUSES, 'active'),
        description: description_value(data, previous)
      }
    end

    def allowed_value(provided, previous, choices, fallback)
      value = provided.presence || previous || fallback
      choices.include?(value) ? value : fallback
    end

    def description_value(data, previous)
      description = data.key?(:description) ? data[:description] : previous&.description
      description.to_s.strip.first(300)
    end

end
