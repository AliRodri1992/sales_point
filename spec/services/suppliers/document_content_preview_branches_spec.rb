# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe Suppliers::DocumentContentPreview do
  def office_blob(content, type:, filename:)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename:, content_type: type, identify: false
    )
  end

  def zipped(entries)
    Zip::OutputStream.write_buffer do |stream|
      entries.each do |name, value|
        stream.put_next_entry(name)
        stream.write(value)
      end
    end.string
  end

  let(:word_ns) { 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }
  let(:excel_ns) { 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' }

  it 'skips a large document before opening its ZIP archive' do
    blob = office_blob('test', type: described_class::DOCX_TYPE, filename: 'large.docx')
    allow(blob).to receive(:byte_size).and_return(10.megabytes + 1)
    expect(blob).not_to receive(:download)

    expect(described_class.new(blob).call).to be_nil
  end

  it 'returns nothing when a DOCX has no document XML entry' do
    blob = office_blob(zipped('notes.txt' => 'Not a Word document'),
                       type: described_class::DOCX_TYPE, filename: 'empty.docx')
    expect(described_class.new(blob).call).to be_nil
  end

  it 'refuses a DOCX entry larger than the extraction budget' do
    xml = "<w:document xmlns:w='#{word_ns}'><w:body><w:p><w:t>#{'x' * (1.megabyte + 1)}</w:t></w:p></w:body></w:document>"
    blob = office_blob(zipped('word/document.xml' => xml),
                       type: described_class::DOCX_TYPE, filename: 'oversized.docx')

    expect(described_class.new(blob).call).to be_nil
  end

  it 'parses DOCX paragraphs but never exposes markup' do
    xml = "<w:document xmlns:w='#{word_ns}'><w:body><w:p><w:t>First</w:t></w:p>" \
          "<w:p><w:t>Second</w:t></w:p></w:body></w:document>"
    blob = office_blob(zipped('word/document.xml' => xml),
                       type: described_class::DOCX_TYPE, filename: 'note.docx')

    expect(described_class.new(blob).call).to eq("First\nSecond")
  end

  it 'skips an XLSX with no first worksheet' do
    blob = office_blob(zipped('xl/workbook.xml' => '<workbook/>'),
                       type: described_class::XLSX_TYPE, filename: 'none.xlsx')
    expect(described_class.new(blob).call).to be_nil
  end

  it 'extracts inline and numeric XLSX cells even without a shared strings file' do
    xml = "<worksheet xmlns='#{excel_ns}'><sheetData><row>" \
          '<c t="inlineStr"><is><t>Widget</t></is></c><c><v>13</v></c>' \
          '</row></sheetData></worksheet>'
    blob = office_blob(zipped('xl/worksheets/sheet1.xml' => xml),
                       type: described_class::XLSX_TYPE, filename: 'stock.xlsx')

    expect(described_class.new(blob).call).to eq("Widget\t13")
  end

  it 'resolves shared strings and handles out of range indexes safely' do
    sheet = "<worksheet xmlns='#{excel_ns}'><sheetData><row><c t='s'><v>0</v></c>" \
            "<c t='s'><v>50</v></c></row></sheetData></worksheet>"
    strings = "<sst xmlns='#{excel_ns}'><si><t>Catalog</t></si></sst>"
    blob = office_blob(zipped('xl/worksheets/sheet1.xml' => sheet, 'xl/sharedStrings.xml' => strings),
                       type: described_class::XLSX_TYPE, filename: 'catalog.xlsx')

    expect(described_class.new(blob).call).to eq("Catalog\t")
  end

  it 'rejects malformed XML rather than returning untrusted fragments' do
    blob = office_blob(zipped('word/document.xml' => '<document><unclosed></document>'),
                       type: described_class::DOCX_TYPE, filename: 'invalid.docx')

    expect(described_class.new(blob).call).to be_nil
  end
end
