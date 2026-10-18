# frozen_string_literal: true

require 'base64'
require 'digest'
require 'cgi'
require 'stringio'
require 'zip'
require 'caxlsx'

# Small, valid, synthetic sample files. Never reattaches an existing filename.
# Real supplier uploads are never replaced or removed.
module SupplierDemoDocuments
  FORMATS = [
    ['constancia', 'pdf', 'application/pdf'], ['nota', 'txt', 'text/plain'],
    ['contrato', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    ['precios', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['identificacion', 'jpg', 'image/jpeg'], ['fotografia', 'png', 'image/png'],
    ['catalogo', 'csv', 'text/csv'],
    ['informacion', 'xml', 'application/xml']
  ].freeze

  # Valid, generated Delta POS swatch, never a personal identity photograph.
  DEMO_JPEG = Base64.decode64(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBAUEBAYFBQUGBgYHCQ4JCQgICRINDQoOFRIWFhUSFBQXGiEcFxgfGRQUHSc' \
    'dHyIjJSUlFhwpLCgkKyEkJST/2wBDAQYGBgkICREJCREkGBQYJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJC' \
    'QkJCQkJCQkJCQkJCT/wAARCAAoACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAA' \
    'gEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6' \
    'Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMX' \
    'Gx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtR' \
    'EAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2N' \
    'zg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6' \
    'wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD6Poorwm9+LniDX5o5l0bUItHeZbd' \
    'ItOmaOSebKMI2nCEknB+WMIxDdTWajc+fr4iNK3N1PY5/E+iW2qppE2q2Ud/J923aUB8/LhcdmO9cA8nsDg1p14zF48fS7K' \
    'Hw+vwomht7rPl2UgY/aSgBLbWhzIwCqSTk8Ak1mW3xJ17wzcyLp/h7U7XTLLy1u9P1CZ50tVYIECuyB4shTgMWX5uFp8jOf' \
    '69BfF+T/wAv67HvNFUtE1H+2NGsNS8ryftltHceXu3bN6hsZwM4z1xRUncndXRdry/4DQRXPgfUIJ4klikv5UeN1DK6mKME' \
    'EHqCO1eoV4F8L/iho3gnQLjTtRttQllku2nDW6Iy7SiLj5mHOVNVFXTOTETjCrBzdlr+h1uv+Ebay8ceDtOttR1aKyka7Mc' \
    'K3bZt1SFPkjk/1iqwUAjdwCdu3NafxP0yz0b4U6hp+n26W9rAsCRxp0A89PzJPJJ5JJJ5rj9Z+MGg6j4s8OaxFaamtvpf2r' \
    'zleNA7eZGFXaN+DyOckfjR49+MGg+KfCd9o9laanHcXHl7GmjQINsisckOT0U9qqz0OaVaio1LNa7fcv1PU/BX/Im6D/2Dr' \
    'b/0UtFHgr/kTdB/7B1t/wCilorNnpU/gXobVFFFBYUUUUAFFFFAH//Z'
  ).freeze

  # Small valid PNG sample for the attachment viewer, not a real identity document.
  DEMO_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAqklEQVR42u3Xyw2AIAwGYCBs5GYO4MEB3MyDQ7iEJw8mDeF' \
    'ZKsQY/t4k4qelPNTHdaovwqiPAjDgbEzLLO6rZdPJI/d16w4TSVjY0hjOA7U8C+Y/lH9nAZalkdMrCb+pWC+i/HgLiGUm6s' \
    'm8l7Sw0W3JD5atGqcon3qJlqkm3v0auqyqfCsrUc8WLJlGPEMIE6jYjwEDBtx3dyqeCGRHhvFSrfF/DBjw7+EbA4Ne9CAjj' \
    'xcAAAAASUVORK5CYII='
  ).freeze

  OBSOLETE_JPEG_SHA256 = '8e3a6a63a12cbe868ada81d8602cc6b0d7c881568fff0d08f842dc3939e12e5c'

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
      existing&.purge
    end

    def obsolete_demo_jpeg?(attachment, extension)
      return false unless extension == 'jpg' && attachment.blob.byte_size == 301

      Digest::SHA256.hexdigest(attachment.blob.download) == OBSOLETE_JPEG_SHA256
    end

    def content_for(extension, supplier)
      return image_contents(extension) if %w[jpg png].include?(extension)

      case extension
      when 'pdf' then pdf_for(supplier)
      when 'txt' then "EJEMPLO - SIN VALIDEZ\nProveedor: #{supplier.code}\nArchivo demostrativo.\n"
      when 'docx' then docx_for(supplier)
      when 'xlsx' then xlsx_for(supplier)
      when 'csv' then "codigo,tipo\n#{supplier.code},demostracion\n"
      when 'xml' then %(<?xml version="1.0" encoding="UTF-8"?>\n<demo><proveedor>#{supplier.code}</proveedor></demo>\n)
      end
    end

    def image_contents(extension)
      { 'jpg' => DEMO_JPEG, 'png' => DEMO_PNG }.fetch(extension)
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

    def docx_for(supplier)
      entries = {
        '[Content_Types].xml' => docx_content_types,
        '_rels/.rels' => docx_relationships,
        'word/document.xml' => docx_body(supplier)
      }
      Zip::OutputStream.write_buffer do |zip|
        entries.each do |path, xml|
          zip.put_next_entry(path)
          zip.write(xml)
        end
      end.string
    end

    def docx_content_types
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      XML
    end

    def docx_relationships
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
      XML
    end

    def docx_body(supplier)
      escaped = CGI.escapeHTML("DEMO #{supplier.code} - SIN VALIDEZ")
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body><w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
      XML
    end

    def xlsx_for(supplier)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Datos de ejemplo') do |sheet|
        sheet.add_row %w[Proveedor Documento Aviso]
        sheet.add_row [supplier.code, 'Lista de precios', 'SIN VALIDEZ']
      end
      package.to_stream.read
    end
  end
end
