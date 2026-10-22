# frozen_string_literal: true

require_relative 'supplier_demo_images'
require_relative 'supplier_demo_document_office'
require 'digest'
require 'stringio'

# Synthetic files are added by a deterministic filename.
# Only the exact known broken demo JPEG can be replaced; user files stay untouched.
module SupplierDemoDocuments
  FORMATS = [
    ['constancia', 'pdf', 'application/pdf'], ['nota', 'txt', 'text/plain'],
    ['contrato', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['precios', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['identificacion', 'jpg', 'image/jpeg'], ['fotografia', 'png', 'image/png'],
    ['catalogo', 'csv', 'text/csv'],
    ['informacion', 'xml', 'application/xml']
  ].freeze

  class << self
    def seed!(supplier:, featured:)
      return if Rails.env.production?

      chosen = featured ? FORMATS : [FORMATS[supplier.code.delete_prefix('SUP-').to_i % FORMATS.length]]
      chosen.each { |name, extension, mime| attach_sample(supplier, name, extension, mime) }
    end

    private

    def attach_sample(supplier, name, extension, mime)
      filename = "delta-demo-#{supplier.code.downcase}-#{name}.#{extension}"
      existing = supplier.documents.attachments.joins(:blob)
                         .find_by(active_storage_blobs: { filename: })
      return if existing && !obsolete_demo_jpeg?(existing, extension)

      supplier.documents.attach(
        io: StringIO.new(content_for(extension, supplier).b),
        filename:, content_type: mime
      )
      if existing
        SupplierDocument.with_deleted.where(attachment_id: existing.id).delete_all
        existing.purge
      end
    end

    def obsolete_demo_jpeg?(attachment, extension)
      return false unless extension == 'jpg' && attachment.blob.byte_size == 301

      Digest::SHA256.hexdigest(attachment.blob.download) == SupplierDemoImages::OBSOLETE_JPEG_SHA256
    end

    def content_for(extension, supplier)
      return image_contents(extension) if %w[jpg png].include?(extension)

      case extension
      when 'pdf' then pdf_for(supplier)
      when 'txt' then "EJEMPLO - SIN VALIDEZ\nProveedor: #{supplier.code}\nArchivo demostrativo.\n"
      when 'docx' then SupplierDemoDocumentOffice.docx_for(supplier)
      when 'xlsx' then SupplierDemoDocumentOffice.xlsx_for(supplier)
      when 'csv' then "codigo,tipo\n#{supplier.code},demostracion\n"
      when 'xml' then %(<?xml version="1.0" encoding="UTF-8"?>\n<demo><proveedor>#{supplier.code}</proveedor></demo>\n)
      end
    end

    def image_contents(extension)
      { 'jpg' => SupplierDemoImages::JPEG, 'png' => SupplierDemoImages::PNG }.fetch(extension)
    end

    def pdf_for(supplier)
      data = +"%PDF-1.4\n"
      offsets = [0]
      pdf_objects(supplier).each_with_index do |body, index|
        offsets << data.bytesize
        data << "#{index + 1} 0 obj\n#{body}\nendobj\n"
      end
      append_pdf_xref(data, offsets)
    end

    def pdf_objects(supplier)
      text = "BT /F1 14 Tf 45 760 Td (DEMO #{supplier.code} - SIN VALIDEZ) Tj ET"
      [
        '<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] ' \
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        "<< /Length #{text.bytesize} >>\nstream\n#{text}\nendstream"
      ]
    end

    def append_pdf_xref(data, offsets)
      start_xref = data.bytesize
      data << "xref\n0 #{offsets.length}\n0000000000 65535 f \n"
      offsets.drop(1).each { |offset| data << format('%010d 00000 n ', offset) << "\n" }
      data << "trailer\n<< /Size #{offsets.length} /Root 1 0 R >>\nstartxref\n#{start_xref}\n%%EOF\n"
    end
  end
end
