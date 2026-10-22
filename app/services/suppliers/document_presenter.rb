# frozen_string_literal: true

module Suppliers
  class DocumentPresenter
    CATEGORIES = %w[contract fiscal catalog technical legal other].freeze
    PREVIEW_TYPES = %w[application/pdf image/png image/jpeg].freeze

    attr_reader :attachment, :document

    def initialize(source)
      @document = source if source.is_a?(SupplierDocument)
      @attachment = document ? document.attachment : source
    end

    def filename = attachment.blob.filename.to_s
    def size = ActiveSupport::NumberHelper.number_to_human_size(attachment.blob.byte_size)
    def format = attachment.blob.filename.extension.downcase

    def description
      return document.description.to_s if document

      metadata['supplier_description'].presence || ''
    end

    def status
      return document.status if document

      metadata['supplier_status'].in?(%w[active inactive]) ? metadata['supplier_status'] : 'active'
    end

    def previewable? = preview_kind != 'none'

    def preview_kind
      case attachment.blob.content_type
      when 'application/pdf' then 'pdf'
      when 'image/png', 'image/jpeg' then 'image'
      when 'text/plain', 'text/csv', 'application/csv', 'text/xml', 'application/xml'
        'text'
      when *Suppliers::OfficeDocumentPdf::CONTENT_TYPES
        return 'pdf' if Suppliers::OfficeDocumentPdf.available?

        types = [Suppliers::DocumentContentPreview::DOCX_TYPE, Suppliers::DocumentContentPreview::XLSX_TYPE]
        return 'text' if attachment.blob.content_type.in?(types)

        'none'
      else 'none'
      end
    end

    def category
      return document.category if document

      given = metadata['supplier_category']
      return given if given.in?(CATEGORIES)

      case filename.downcase
      when /contrato|contract/ then 'contract'
      when /fiscal|sat|rfc|constancia|tax|certificate/ then 'fiscal'
      when /cat[aá]logo|catalog|lista.de.precios/ then 'catalog'
      when /especificaci[oó]n|technical|ficha.t[eé]cnica/ then 'technical'
      when /identificaci[oó]n|legal|acta|poder/ then 'legal'
      else 'other'
      end
    end

    def icon
      case format
      when 'pdf' then 'pdf'
      when 'doc', 'docx' then 'word'
      when 'xls', 'xlsx', 'csv' then 'excel'
      when 'png', 'jpg', 'jpeg' then 'image'
      when 'txt', 'xml' then 'text'
      else 'file'
      end
    end

    private

    def metadata = attachment.blob.custom_metadata
  end
end
