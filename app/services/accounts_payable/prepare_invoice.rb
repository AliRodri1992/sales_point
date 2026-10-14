# frozen_string_literal: true

module AccountsPayable
  class PrepareInvoice
    def self.call(invoice:, attributes:, organization:)
      new(invoice:, attributes:, organization:).call
    end

    def initialize(invoice:, attributes:, organization:)
      @invoice = invoice
      @attributes = attributes
      @organization = organization
    end

    def call
      supplier = find_supplier!
      @invoice.assign_attributes(@attributes.except(:xml_document, :pdf_document).merge(supplier:))
      attach_xml!
      assign_dates!(supplier)
      attach_pdf!
      @invoice
    end

    private

    def find_supplier!
      id = @attributes[:supplier_id] || @invoice.supplier_id
      supplier = @organization.suppliers.not_deleted.find_by(id:)
      raise ArgumentError, 'Invalid supplier' unless supplier

      supplier
    end

    def attach_xml!
      upload = @attributes[:xml_document]
      return if upload.blank?

      raw = upload.read
      AccountsPayable::ImportCfdi.call(invoice: @invoice, xml: raw)
      @invoice.xml_document.attach(
        io: StringIO.new(raw), filename: upload.original_filename, content_type: 'application/xml'
      )
    end

    def assign_dates!(supplier)
      @invoice.issued_on ||= Date.current
      @invoice.received_on ||= Date.current
      @invoice.due_on ||= @invoice.issued_on + supplier.credit_days.days
    end

    def attach_pdf!
      upload = @attributes[:pdf_document]
      @invoice.pdf_document.attach(upload) if upload.present?
    end
  end
end
