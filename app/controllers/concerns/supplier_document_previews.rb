# frozen_string_literal: true

# Streams safe, non-executable previews after document authorization.
module SupplierDocumentPreviews
  private

  def send_text_preview(attachment)
    text = attachment.blob.download.byteslice(0, 60_000).force_encoding(Encoding::UTF_8).scrub
    send_plain_text(attachment, text)
  end

  def send_office_pdf_preview(attachment)
    document = SupplierDocument.find_by!(attachment_id: attachment.id)
    data = nil
    document.with_lock do
      data = document.preview_pdf.attached? ? document.preview_pdf.download : create_office_preview(document)
    end
    return head :unsupported_media_type unless data

    response.headers['X-Content-Type-Options'] = 'nosniff'
    send_data data, filename: "#{attachment.blob.filename.base}.pdf",
                    type: 'application/pdf', disposition: 'inline'
  end

  def create_office_preview(document)
    pdf = Suppliers::OfficeDocumentPdf.new(document.attachment.blob).call
    return if pdf.blank?

    document.preview_pdf.attach(
      io: StringIO.new(pdf), filename: "#{document.attachment.blob.filename.base}.pdf",
      content_type: 'application/pdf'
    )
    pdf
  end

  def send_office_preview(attachment)
    text = Suppliers::DocumentContentPreview.new(attachment.blob).call
    return head :unsupported_media_type if text.blank?

    send_plain_text(attachment, text)
  end

  def send_plain_text(attachment, text)
    response.headers['X-Content-Type-Options'] = 'nosniff'
    send_data text, filename: attachment.blob.filename.to_s,
                    type: 'text/plain; charset=utf-8', disposition: 'inline'
  end
end
