# frozen_string_literal: true

# Supplier attachment MIME allowlist and size validation.
module SupplierDocumentTypes
  ALLOWED_DOCUMENT_TYPES = %w[
    application/pdf image/png image/jpeg text/plain text/csv application/csv
    application/xml text/xml application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/msword application/vnd.ms-excel
  ].freeze

  def documents_are_safe
    documents.each do |document|
      next unless document.blob

      errors.add(:documents, :invalid) unless document.blob.content_type.in?(ALLOWED_DOCUMENT_TYPES)
      errors.add(:documents, :file_too_large) if document.blob.byte_size > 10.megabytes
    end
  end
end
