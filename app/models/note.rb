# frozen_string_literal: true

class Note < ApplicationRecord
  has_paper_trail only: %i[body deleted_at], save_changes: true,
                  if: ->(record) { record.notable_type == 'Branch' }
  include RestrictsClosedBranchMutations
  belongs_to :notable, polymorphic: true
  belongs_to :organization, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :kind, presence: true, length: { maximum: 30 }
  validates :body, presence: true, length: { maximum: 20_000 }
  validate :matching_organization

  scope :general, -> { where(kind: 'general') }

  private

  def matching_organization
    return unless notable.respond_to?(:note_organization)

    expected = notable.note_organization
    errors.add(:organization, :invalid) if expected && organization_id != expected.id
  end
end
