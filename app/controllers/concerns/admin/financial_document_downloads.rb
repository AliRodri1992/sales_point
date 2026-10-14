# frozen_string_literal: true

module Admin
  module FinancialDocumentDownloads
    extend ActiveSupport::Concern

    private

    def send_financial_attachment(attachment, filename, content_type)
      return head :not_found unless attachment.attached?

      response.headers['Cache-Control'] = 'no-store'
      send_data attachment.download, filename:, type: content_type, disposition: 'attachment'
    end
  end
end
