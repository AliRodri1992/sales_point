# frozen_string_literal: true

# Streams safe, non-executable previews after document authorization.
module SupplierDocumentPreviews
  private

  def send_text_preview(attachment)
    text = attachment.blob.download.byteslice(0, 60_000).force_encoding(Encoding::UTF_8).scrub
    send_plain_text(attachment, text)
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
