# frozen_string_literal: true

Rails.application.config.to_prepare do
  ActiveStorage::Attachment.include SupplierDocumentAttachmentTracking
end
