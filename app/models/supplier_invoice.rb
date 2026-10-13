# frozen_string_literal: true

class SupplierInvoice < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :supplier
  belongs_to :purchase_order, optional: true
  belongs_to :currency
  belongs_to :created_by, class_name: 'User'
  has_one :account_payable, dependent: :restrict_with_exception
  has_many :supplier_invoice_lines, dependent: :restrict_with_exception
  has_many :supplier_invoice_receipts, dependent: :restrict_with_exception
  has_many :goods_receipts, through: :supplier_invoice_receipts
  has_one_attached :xml_document
  has_one_attached :pdf_document

  enum :status, { draft: 'draft', posted: 'posted', cancelled: 'cancelled' }, validate: true
  enum :source, { manual: 'manual', cfdi: 'cfdi' }, validate: true

  validates :issued_on, :received_on, :due_on, presence: true
  validates :total, numericality: { greater_than: 0 }
  validates :subtotal, :tax_amount, :discount, numericality: { greater_than_or_equal_to: 0 }
  validates :exchange_rate, numericality: { greater_than: 0 }
  validates :uuid, uniqueness: { scope: :organization_id }, allow_blank: true
  validate :consistent_relations
  validate :valid_documents
  before_validation :normalize_fiscal_data

  private

  def consistent_relations
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
    if purchase_order && (purchase_order.organization_id != organization_id || purchase_order.supplier_id != supplier_id)
      errors.add(:purchase_order, :invalid)
    end
  end

  def valid_documents
    { xml_document: %w[application/xml text/xml], pdf_document: %w[application/pdf] }.each do |name, types|
      attachment = public_send(name)
      next unless attachment.attached?

      errors.add(name, :invalid) unless types.include?(attachment.blob.content_type)
      errors.add(name, :too_long) if attachment.blob.byte_size > 10.megabytes
    end
  end

  def normalize_fiscal_data
    self.uuid = uuid.to_s.strip.upcase.presence
    self.issuer_rfc = issuer_rfc.to_s.strip.upcase.presence
    self.receiver_rfc = receiver_rfc.to_s.strip.upcase.presence
  end
end
