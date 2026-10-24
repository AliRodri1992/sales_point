# frozen_string_literal: true

module Admin
  class SupplierDocumentsController < ApplicationController
    include SupplierAuditTrail
    include SupplierDocumentPreviews
    include SupplierDocumentManagement

    TEXT_PREVIEW_TYPES = %w[text/plain text/csv application/csv text/xml application/xml].freeze
    OFFICE_PREVIEW_TYPES = Suppliers::OfficeDocumentPdf::CONTENT_TYPES.freeze
    PREVIEW_TYPES = (%w[application/pdf image/png image/jpeg] + TEXT_PREVIEW_TYPES +
                     OFFICE_PREVIEW_TYPES).freeze
    CATEGORIES = %w[contract fiscal catalog technical legal other].freeze
    STATUSES = %w[active inactive].freeze

    before_action :authenticate_user!

    def create
      supplier = authorized_supplier(:manage_documents?)
      files = document_files
      return reject_file(supplier) unless files.size.between?(1, 10) && files.all? { |file| valid_file?(file) }

      persist_uploaded_documents(supplier, files)
      redirect_documents(supplier, :uploaded)
    end

    def update
      supplier = authorized_supplier(:manage_documents?)
      document = current_document(supplier)
      return replace_document(supplier, document) if document_file.present?

      document.update!(**metadata_attributes(document), updated_by: current_user)
      redirect_documents(supplier, :updated)
    end

    def preview
      attachment = authorized_attachment(:view_documents?)
      raise ActiveRecord::RecordNotFound unless attachment.blob

      return head :unsupported_media_type unless attachment.blob.content_type.in?(PREVIEW_TYPES)

      response.headers['Content-Security-Policy'] = "frame-ancestors 'self'"
      return send_office_document_preview(attachment) if attachment.blob.content_type.in?(OFFICE_PREVIEW_TYPES)
      return send_text_preview(attachment) if attachment.blob.content_type.in?(TEXT_PREVIEW_TYPES)

      send_attachment(attachment, disposition: 'inline')
    end

    def send_office_document_preview(attachment)
      return send_office_pdf_preview(attachment) if Suppliers::OfficeDocumentPdf.available?

      modern = [Suppliers::DocumentContentPreview::DOCX_TYPE, Suppliers::DocumentContentPreview::XLSX_TYPE]
      return send_office_preview(attachment) if attachment.blob.content_type.in?(modern)

      head :unsupported_media_type
    end

    def download
      send_attachment(authorized_attachment(:view_documents?), disposition: 'attachment')
    end

    def destroy
      supplier = authorized_supplier(:manage_documents?)
      document = current_document(supplier)
      document.update!(deleted_at: Time.current, deleted_by: current_user)
      notify_document_deleted(supplier, document.attachment_id)
      redirect_documents(supplier, :deleted)
    end

    def restore
      supplier = authorized_supplier(:manage_documents?)
      document = supplier.supplier_documents.trashed.find_by!(attachment_id: params[:document_id])
      document.update!(deleted_at: nil, deleted_by: nil, updated_by: current_user)
      redirect_documents(supplier, :updated)
    end

    def history
      supplier = authorized_supplier(:view_documents?)
      document = document_for(supplier)
      @supplier = supplier
      @versions = supplier.supplier_documents.where(series_id: document.series_id).order(revision_number: :desc)
    end

    def version_download
      supplier = authorized_supplier(:view_documents?)
      send_attachment(document_for(supplier).attachment, disposition: 'attachment')
    end

    private

    def authorized_supplier(permission)
      raise ActiveRecord::RecordNotFound unless current_organization

      supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize supplier, permission
      supplier
    end

    def authorized_attachment(permission)
      supplier = authorized_supplier(permission)
      current_document(supplier).attachment
    end

    def send_attachment(attachment, disposition:)
      raise ActiveRecord::RecordNotFound unless attachment.blob

      response.headers['X-Content-Type-Options'] = 'nosniff'
      send_data attachment.blob.download,
                filename: attachment.blob.filename.to_s,
                type: attachment.blob.content_type,
                disposition:
    end

    def document_params
      params.fetch(:document, ActionController::Parameters.new)
            .permit(:file, :category, :description, :status, files: [])
    end

    def document_files
      Array(document_params[:files]).compact_blank.presence || Array(document_file).compact_blank
    end

    def document_file
      document_params[:file]
    end

    def valid_file?(file)
      file.respond_to?(:content_type) && file.respond_to?(:size) &&
        file.size.positive? && file.size <= 10.megabytes &&
        file.content_type.in?(SupplierDocumentTypes::ALLOWED_DOCUMENT_TYPES)
    end

    def reject_file(supplier)
      redirect_to admin_supplier_path(supplier, tab: 'documents'),
                  alert: t('admin.supplier_documents.invalid_file')
    end

    def redirect_documents(supplier, action)
      redirect_to admin_supplier_path(supplier, tab: 'documents'),
                  notice: t("admin.supplier_documents.messages.#{action}")
    end

    def notify_document_deleted(supplier, document_id)
      Suppliers::NotifyService.call(action: 'document_deleted', supplier:, user: current_user,
                                    subject: supplier, event_token: document_id)
    end
  end
end
