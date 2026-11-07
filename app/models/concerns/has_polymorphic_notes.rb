# frozen_string_literal: true

# Existing forms still submit a :notes field, but the content is stored only
# in the polymorphic notes table, not in the owner record.
module HasPolymorphicNotes
  extend ActiveSupport::Concern

  included do
    attribute :notes, :text
    has_many :note_entries, class_name: 'Note', as: :notable, inverse_of: :notable, dependent: :destroy
    after_save :sync_general_note, if: :note_field_assigned?
  end

  def notes
    return self[:notes] if note_field_assigned?

    general_note_entry&.body
  end

  def notes=(value)
    @note_field_assigned = true
    self[:notes] = value.to_s.strip.presence
  end

  def note_body = notes

  def note_body=(value)
    self.notes = value
  end

  def note_organization
    return organization if respond_to?(:organization) && organization.present?

    parent_note_organization
  end

  private

  def note_field_assigned?
    @note_field_assigned == true
  end

  def general_note_entry
    return note_entries.find { |entry| entry.kind == 'general' } if association(:note_entries).loaded?

    note_entries.general.first if persisted?
  end

  def parent_note_organization
    %i[supplier contactable goods_receipt purchase_request purchase_return purchase_order].each do |name|
      next unless respond_to?(name)

      parent = public_send(name)
      next unless parent

      return parent if parent.is_a?(Organization)
      return parent.organization if parent.respond_to?(:organization) && parent.organization.present?
    end
    nil
  end

  def sync_general_note
    entry = note_entries.general.first
    if self[:notes].present?
      write_general_note(entry, self[:notes])
    else
      entry&.destroy!
    end
  ensure
    @note_field_assigned = false
  end

  def write_general_note(entry, content)
    organization = note_organization
    return note_entries.create!(kind: 'general', body: content, organization:) unless entry
    return if entry.body == content && entry.organization_id == organization&.id

    entry.update!(body: content, organization:)
  end
end
