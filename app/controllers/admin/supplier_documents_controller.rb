# frozen_string_literal: true

module Admin
  class SupplierDocumentsController < ApplicationController
    include SupplierAuditTrail

    PREVIEW_TYPES = %w[application/pdf image/png image/jpeg].freeze
    CATEGORIES = %w[contract fiscal catalog technical legal other].freeze
    STATUSES = %w[active inactive].freeze

    before_action :authenticate_user!

    def create
      supplier = authorized_supplier(:manage_documents?)
      return reject_file(supplier) unless valid_file?(document_file)

      supplier.documents.attach(document_file)
      attachment = supplier.documents.attachments.order(:id).last
      update_metadata(attachment.blob)
      redirect_documents(supplier, :uploaded)
    end

    def update
      supplier = authorized_supplier(:manage_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      if document_file.present?
        return reject_file(supplier) unless valid_file?(document_file)

        supplier.documents.attach(document_file)
        replacement = supplier.documents.attachments.order(:id).last
        update_metadata(replacement.blob, previous: attachment.blob)
        attachment.purge
        redirect_documents(supplier, :replaced)
      else
        update_metadata(attachment.blob)
        redirect_documents(supplier, :updated)
      end
    end

    def preview
      supplier = authorized_supplier(:view_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      return head :unsupported_media_type unless attachment.blob.content_type.in?(PREVIEW_TYPES)

      response.headers['X-Content-Type-Options'] = 'nosniff'
      response.headers['Content-Security-Policy'] = "default-src 'none'; style-src 'unsafe-inline'; sandbox"
      send_data attachment.blob.download,
                filename: attachment.blob.filename.to_s,
                type: attachment.blob.content_type,
                disposition: 'inline'
    end

    def download
      supplier = authorized_supplier(:view_documents?)
      attachment = supplier.documents.attachments.find(params[:document_id])
      response.headers['X-Content-Type-Options'] = 'nosniff'
      send_data attachment.blob.download,
                filename: attachment.blob.filename.to_s,
                type: attachment.blob.content_type,
                disposition: 'attachment'
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
      supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize supplier, permission
      supplier
    end

    def document_params
      params.fetch(:document, {}).permit(:file, :category, :description, :status)
    end

    def document_file
      document_params[:file]
    end

    def valid_file?(file)
      file.present? && file.size <= 10.megabytes &&
        file.content_type.in?(SupplierDocumentTypes::ALLOWED_DOCUMENT_TYPES)
    end

    def reject_file(supplier)
      redirect_to admin_supplier_path(supplier, tab: 'documents'),
                  alert: t('admin.supplier_documents.invalid_file')
    end

    def update_metadata(blob, previous: nil)
      prior = previous&.custom_metadata || blob.custom_metadata
      data = document_params
      category = data[:category].presence || prior['supplier_category'] || 'other'
      status = data[:status].presence || prior['supplier_status'] || 'active'
      category = 'other' unless category.in?(CATEGORIES)
      status = 'active' unless status.in?(STATUSES)

      blob.update!(metadata: blob.metadata.merge('custom' => blob.custom_metadata.merge(
        'supplier_category' => category,
        'supplier_status' => status,
        'supplier_description' => data.key?(:description) ? data[:description].to_s.strip.first(300) :
          prior['supplier_description'].to_s.first(300)
      )))
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
