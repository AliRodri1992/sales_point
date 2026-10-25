# frozen_string_literal: true

require 'zip'

module Suppliers
  # Rejects mismatched or malformed Office documents before PDF conversion.
  # MIME type and extension alone are not proof of an Office file.
  class OfficeDocumentFormatValidator
    MODERN_FORMATS = {
      'docx' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'word/document.xml'],
      'xlsx' => ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'xl/workbook.xml']
    }.freeze
    LEGACY_FORMATS = {
      'doc' => 'application/msword',
      'xls' => 'application/vnd.ms-excel'
    }.freeze
    OLE_SIGNATURE = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1].pack('C*').freeze
    ZIP_SIGNATURE = "PK\x03\x04".b.freeze
    MAX_MANIFEST_BYTES = 1.megabyte
    PACKAGE_NAMESPACE = 'http://schemas.openxmlformats.org/package/2006/content-types'

    def initialize(blob)
      @blob = blob
    end

    def valid?
      return false unless @blob.byte_size.positive? && @blob.byte_size <= 10.megabytes

      extension = @blob.filename.extension.downcase
      return valid_modern?(MODERN_FORMATS.fetch(extension)) if MODERN_FORMATS.key?(extension)

      expected_type = LEGACY_FORMATS[extension]
      expected_type.present? && @blob.content_type == expected_type && @blob.download.start_with?(OLE_SIGNATURE)
    rescue Zip::Error, Nokogiri::XML::SyntaxError, IOError, SystemCallError
      false
    end

    private

    def valid_modern?(format)
      type, main_entry = format
      return false unless @blob.content_type == type

      bytes = @blob.download
      return false unless bytes.start_with?(ZIP_SIGNATURE)

      Zip::File.open_buffer(bytes) do |zip|
        manifest = zip.find_entry('[Content_Types].xml')
        main = zip.find_entry(main_entry)
        next false unless manifest && main
        next false unless manifest.size.between?(1, MAX_MANIFEST_BYTES) && main.size.positive?

        xml = Nokogiri::XML(manifest.get_input_stream.read(MAX_MANIFEST_BYTES + 1)) do |config|
          config.strict.nonet
        end
        xml.root&.name == 'Types' && xml.root&.namespace&.href == PACKAGE_NAMESPACE
      end
    end
  end
end
