# frozen_string_literal: true

require 'cgi'
require 'zip'
require 'caxlsx'

# Builds valid synthetic Office files independent of supplier attachment lifecycle.
module SupplierDemoDocumentOffice
  class << self
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
