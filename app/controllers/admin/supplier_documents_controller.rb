# frozen_string_literal: true

module Admin
  class SupplierDocumentsController < ApplicationController
    include SupplierAuditTrail
    include SupplierDocumentPreviews

    TEXT_PREVIEW_TYPES = %w[text/plain text/csv application/csv text/xml application/xml].freeze
    OFFICE_PREVIEW_TYPES = [Suppliers::DocumentContentPreview::DOCX_TYPE,
                            Suppliers::DocumentContentPreview::XLSX_TYPE].freeze
    PREVIEW_TYPES = (%w[application/pdf image/png image/jpeg] + TEXT_PREVIEW_TYPES +
                     OFFICE_PREVIEW_TYPES).freeze
    CATEGORIES = %w[contract fiscal catalog technical legal other].freeze
    STATUSES = %w[active inactive].freeze

    before_action :authenticate_user!

    def create
      supplier = authorized_supplier(:manage_documents?)
      files = document_files
      return reject_file(supplier) unless files.size.between?(1, 10) && files.all? { |file| valid_file?(file) }

      supplier.documents.attach(files)
      supplier.documents.attachments.order(:id).last(files.size).each do |attachment|
        update_metadata(attachment.blob)
      end
      redirect_documents(supplier, :uploaded)
    end

    def update
      supplier = authorized_supplier(:manage_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      return replace_document(supplier, attachment) if document_file.present?

      update_metadata(attachment.blob)
      redirect_documents(supplier, :updated)
    end

    def preview
      attachment = authorized_attachment(:view_documents?)
      return head :unsupported_media_type unless attachment.blob.content_type.in?(PREVIEW_TYPES)

      response.headers['Content-Security-Policy'] = "frame-ancestors 'self'"
      return send_text_preview(attachment) if attachment.blob.content_type.in?(TEXT_PREVIEW_TYPES)
      return send_office_preview(attachment) if attachment.blob.content_type.in?(OFFICE_PREVIEW_TYPES)

      send_attachment(attachment, disposition: 'inline')
    end

    def download
      send_attachment(authorized_attachment(:view_documents?), disposition: 'attachment')
    end

    def destroy
      supplier = authorized_supplier(:manage_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      id = attachment.id
      attachment.purge
      notify_document_deleted(supplier, id)
      redirect_documents(supplier, :deleted)
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
      supplier.documents.attachments.find(params[:document_id])
    end

    def send_attachment(attachment, disposition:)
      response.headers['X-Content-Type-Options'] = 'nosniff'
      send_data attachment.blob.download,
                filename: attachment.blob.filename.to_s,
                type: attachment.blob.content_type,
                disposition:
    end

    def replace_document(supplier, attachment)
      return reject_file(supplier) unless valid_file?(document_file)

      supplier.documents.attach(document_file)
      replacement = supplier.documents.attachments.order(:id).last
      update_metadata(replacement.blob, previous: attachment.blob)
      attachment.purge
      redirect_documents(supplier, :replaced)
    end

    def document_params
      params.fetch(:document, ActionController::Parameters.new)
            .permit(:file, :category, :description, :status, files: [])
    end

    def document_files
      uploaded = Array(document_params[:files]).compact_blank
      uploaded.presence || Array(document_file).compact_blank
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

    def update_metadata(blob, previous: nil)
      prior = previous&.custom_metadata || blob.custom_metadata
      metadata = blob.custom_metadata.merge(document_metadata(prior))
      blob.update!(metadata: blob.metadata.merge('custom' => metadata))
    end

    def document_metadata(prior)
      data = document_params
      {
        'supplier_category' => allowed_value(data[:category], prior['supplier_category'], CATEGORIES, 'other'),
        'supplier_status' => allowed_value(data[:status], prior['supplier_status'], STATUSES, 'active'),
        'supplier_description' => description_value(data, prior)
      }
    end

    def allowed_value(provided, previous, choices, fallback)
      value = provided.presence || previous || fallback
      choices.include?(value) ? value : fallback
    end

    def description_value(data, previous)
      description = data.key?(:description) ? data[:description] : previous['supplier_description']
      description.to_s.strip.first(300)
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
