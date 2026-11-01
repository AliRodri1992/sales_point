# frozen_string_literal: true

module SupplierDocumentManagement
  private

  def persist_uploaded_documents(supplier, files)
    supplier.with_lock do
      existing_ids = supplier.documents.attachments.pluck(:id)
      supplier.documents.attach(files)
      attachments = supplier.documents.attachments.where.not(id: existing_ids).order(:id).to_a
      raise ActiveRecord::RecordInvalid, supplier unless attachments.size == files.size

      attachments.each do |attachment|
        document = supplier.supplier_documents.with_deleted.find_or_initialize_by(attachment:)
        document.assign_attributes(uploaded_by: current_user, **metadata_attributes)
        document.save!
      end
    end
  end

  def replace_document(supplier, document)
    return reject_file(supplier) unless valid_file?(document_file)

    supplier.with_lock { persist_replacement(supplier, document) }
    redirect_documents(supplier, :replaced)
  end

  def persist_replacement(supplier, document)
    existing_ids = supplier.documents.attachments.pluck(:id)
    supplier.documents.attach(document_file)
    attachment = supplier.documents.attachments.where.not(id: existing_ids).order(:id).last
    raise ActiveRecord::RecordInvalid, supplier unless attachment

    document.update!(current_version: false, updated_by: current_user)
    replacement = supplier.supplier_documents.with_deleted.find_or_initialize_by(attachment:)
    replacement.assign_attributes(
      uploaded_by: current_user, previous_version: document, series_id: document.series_id,
      revision_number: document.revision_number + 1, **metadata_attributes(document)
    )
    replacement.save!
  end

  def current_document(supplier)
    supplier.supplier_documents.visible.find_by!(attachment_id: params[:document_id])
  end

  def document_for(supplier)
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
