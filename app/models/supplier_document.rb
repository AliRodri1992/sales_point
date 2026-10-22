# frozen_string_literal: true

class SupplierDocument < ApplicationRecord
  CATEGORIES = %w[contract fiscal catalog technical legal other].freeze
  STATUSES = %w[active inactive].freeze

  has_paper_trail
  has_one_attached :preview_pdf

  belongs_to :supplier
  belongs_to :attachment, class_name: 'ActiveStorage::Attachment'
  belongs_to :previous_version, class_name: 'SupplierDocument', optional: true
  belongs_to :uploaded_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  belongs_to :deleted_by, class_name: 'User', optional: true

  scope :visible, -> { where(current_version: true, deleted_at: nil) }
  scope :trashed, -> { with_deleted.where(current_version: true).where.not(deleted_at: nil) }

  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES }
  validates :description, length: { maximum: 300 }
  validates :revision_number, numericality: { only_integer: true, greater_than: 0 }
  validates :attachment_id, uniqueness: true
  validates :series_id, presence: true
  validate :attachment_matches_supplier

  before_validation :set_series_id, on: :create

  def self.import_existing!(supplier)
    supplier.with_lock do
      tracked = supplier.supplier_documents.with_deleted.select(:attachment_id)
      ActiveStorage::Attachment.where(record: supplier, name: 'documents')
                               .where.not(id: tracked).includes(:blob).find_each do |attachment|
        presenter = Suppliers::DocumentPresenter.new(attachment)
        supplier.supplier_documents.create!(
          attachment:, category: presenter.category, status: presenter.status,
          description: presenter.description.first(300), revision_number: 1, current_version: true
        )
      end
    end
  end

  private

  def set_series_id
    self.series_id ||= SecureRandom.uuid
  end

  def attachment_matches_supplier
    return unless attachment && supplier

    matches = attachment.record_type == 'Supplier' &&
              attachment.record_id == supplier.id && attachment.name == 'documents'
    errors.add(:attachment, :invalid) unless matches
  end
end
