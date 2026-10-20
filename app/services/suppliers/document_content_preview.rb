# frozen_string_literal: true

require 'zip'

module Suppliers
  # Extracts readable, non-executable text from modern Office documents.
  # ZIP/XML limits prevent oversized decompression and unsafe HTML rendering.
  class DocumentContentPreview
    DOCX_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    XLSX_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    MAX_XML_BYTES = 1.megabyte
    MAX_TEXT_CHARS = 60_000

    def initialize(blob)
      @blob = blob
    end

    def call
      return unless @blob.content_type.in?([DOCX_TYPE, XLSX_TYPE])
      return if @blob.byte_size > 10.megabytes

      text = nil
      Zip::File.open_buffer(@blob.download) do |zip|
        text = @blob.content_type == DOCX_TYPE ? docx_text(zip) : xlsx_text(zip)
      end
      text
    rescue Zip::Error, Nokogiri::XML::SyntaxError, ArgumentError
      nil
    end

    private

    def read_xml(zip, path)
      entry = zip.find_entry(path)
      return unless entry && entry.size <= MAX_XML_BYTES

      data = entry.get_input_stream.read(MAX_XML_BYTES + 1)
      return if data.bytesize > MAX_XML_BYTES

      Nokogiri::XML(data) { |config| config.strict.nonet }
    end

    def docx_text(zip)
      xml = read_xml(zip, 'word/document.xml')
      return unless xml

      namespaces = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }
      paragraphs = xml.xpath('//w:body//w:p', namespaces)
      lines = paragraphs.map { |paragraph| paragraph.xpath('.//w:t', namespaces).map(&:text).join }
      lines.compact_blank.join("\n").first(MAX_TEXT_CHARS)
    end

    def xlsx_text(zip)
      sheet = read_xml(zip, 'xl/worksheets/sheet1.xml')
      return unless sheet

      namespaces = { 'x' => 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' }
      strings = shared_strings(zip, namespaces)
      rows = sheet.xpath('//x:sheetData/x:row', namespaces).first(200)
      rows.map { |row| row_text(row, namespaces, strings) }.join("\n").first(MAX_TEXT_CHARS)
    end

    def shared_strings(zip, namespaces)
      xml = read_xml(zip, 'xl/sharedStrings.xml')
      return [] unless xml

      xml.xpath('//x:si', namespaces).map do |item|
        item.xpath('.//x:t', namespaces).map(&:text).join
      end
    end

    def row_text(row, namespaces, strings)
      row.xpath('./x:c', namespaces).map do |cell|
        raw = cell.at_xpath('./x:v', namespaces)&.text
        case cell['t']
        when 's' then strings[raw.to_i].to_s
        when 'inlineStr' then cell.xpath('.//x:t', namespaces).map(&:text).join
        else raw.to_s
        end
      end.join("\t")
    end
  end
end
