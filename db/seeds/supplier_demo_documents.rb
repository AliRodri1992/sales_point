# frozen_string_literal: true

require 'base64'
require 'csv'
require 'cgi'
require 'stringio'
require 'zip'
require 'caxlsx'

# Small, valid, synthetic sample files. Never reattaches an existing filename.
# Real supplier uploads are never replaced or removed.
module SupplierDemoDocuments
  FORMATS = [
    ['constancia', 'pdf', 'application/pdf'],
    ['nota', 'txt', 'text/plain'],
    ['contrato', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['precios', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['identificacion', 'jpg', 'image/jpeg'],
    ['catalogo', 'csv', 'text/csv'],
    ['informacion', 'xml', 'application/xml']
  ].freeze

  # Tiny valid JPEG; synthetic colored swatch, never a personal document.
  DEMO_JPEG = Base64.decode64(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsL' \
    'DBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/' \
    '2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy' \
    'MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAQABADASIAAhEBAxEB/8QA' \
    'FQABAQAAAAAAAAAAAAAAAAAAAAb/xAAdEAACAgIDAQAAAAAAAAAAAAABAgMR' \
    'AAQhBRIx/8QAFQEBAQAAAAAAAAAAAAAAAAAAAwT/xAAZEQADAQEBAAAAAAAA' \
    'AAAAAAAAAQIRAyH/2gAMAwEAAhEDEQA/AMTiO4CXcY1KRTVLV5TsSVSOxXWw' \
    'ggmh8Fz0xZsCPkxbUcCf/9k='
  ).freeze

  class << self
    def seed!(supplier:, featured:)
      return if Rails.env.production?

      chosen = featured ? FORMATS : [FORMATS[supplier.code.delete_prefix('SUP-').to_i % FORMATS.length]]
      chosen.each { |name, extension, mime| attach_sample(supplier, name, extension, mime) }
    end

    private

    def attach_sample(supplier, name, extension, mime)
      filename = "delta-demo-#{supplier.code.downcase}-#{name}.#{extension}"
      return if supplier.documents.attachments.joins(:blob)
                        .exists?(active_storage_blobs: { filename: })

      supplier.documents.attach(
        io: StringIO.new(content_for(extension, supplier).b),
        filename:, content_type: mime
      )
    end

    def content_for(extension, supplier)
      case extension
      when 'pdf' then pdf_for(supplier)
      when 'txt' then "EJEMPLO - SIN VALIDEZ\nProveedor: #{supplier.code}\nArchivo demostrativo.\n"
      when 'docx' then docx_for(supplier)
      when 'xlsx' then xlsx_for(supplier)
      when 'jpg' then DEMO_JPEG
      when 'csv' then CSV.generate { |csv| csv << %w[codigo tipo]; csv << [supplier.code, 'demostracion'] }
      when 'xml' then %(<?xml version="1.0" encoding="UTF-8"?>\n<demo><proveedor>#{supplier.code}</proveedor></demo>\n)
      end
    end

    def pdf_for(supplier)
      stream = "BT /F1 14 Tf 45 760 Td (DEMO #{supplier.code} - SIN VALIDEZ) Tj ET"
      objects = [
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
      ]
      data = +"%PDF-1.4\n"
      offsets = [0]
      objects.each_with_index do |body, index|
        offsets << data.bytesize
        data << "#{index + 1} 0 obj\n#{body}\nendobj\n"
      end
      start_xref = data.bytesize
      data << "xref\n0 #{offsets.length}\n0000000000 65535 f \n"
      offsets.drop(1).each { |offset| data << format('%010d 00000 n ', offset) << "\n" }
      data << "trailer\n<< /Size #{offsets.length} /Root 1 0 R >>\nstartxref\n#{start_xref}\n%%EOF\n"
      data
    end

    def docx_for(supplier)
      escaped = CGI.escapeHTML("DEMO #{supplier.code} - SIN VALIDEZ")
      entries = {
        '[Content_Types].xml' => <<~XML,
          <?xml version="1.0" encoding="UTF-8"?>
          <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          </Types>
        XML
        '_rels/.rels' => <<~XML,
          <?xml version="1.0" encoding="UTF-8"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
          </Relationships>
        XML
        'word/document.xml' => <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
        XML
      }
      Zip::OutputStream.write_buffer do |zip|
        entries.each do |path, xml|
          zip.put_next_entry(path)
          zip.write(xml)
        end
      end.string
    end

    def xlsx_for(supplier)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Datos de ejemplo') do |sheet|
        sheet.add_row ['Proveedor', 'Documento', 'Aviso']
        sheet.add_row [supplier.code, 'Lista de precios', 'SIN VALIDEZ']
      end
      package.to_stream.read
    end
  end
end
