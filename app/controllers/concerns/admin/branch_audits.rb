# frozen_string_literal: true

module Admin
  # Read-only audit feed for branch attributes and polymorphic contact details.
  module BranchAudits
    AUDITED_FIELDS = {
      'Branch' => %w[name code contact_email],
      'Address' => %w[
        street exterior_number interior_number neighborhood city state postal_code country_id reference_notes
      ],
      'Phone' => %w[number kind primary whatsapp_enabled],
      'Note' => %w[body]
    }.freeze

    private

    def load_branch_change_events
      owner_ids = {
        'Branch' => [@branch.id],
        'Address' => Array(@branch.address&.id),
        'Phone' => @branch.phones.pluck(:id),
        'Note' => @branch.note_entries.pluck(:id)
      }
      events = owner_ids.flat_map do |type, ids|
        next [] if ids.empty?

        PaperTrail::Version.where(item_type: type, item_id: ids)
                           .order(created_at: :desc).limit(20).to_a
      end
      @branch_change_events = events.filter_map do |event|
        fields = event.changeset.to_h.slice(*AUDITED_FIELDS.fetch(event.item_type))
        { event:, fields: } if fields.present?
      end.sort_by { |item| item[:event].created_at }.reverse.first(20)
      ids = @branch_change_events.filter_map { |item| Integer(item[:event].whodunnit, exception: false) }
      @branch_change_actors = User.where(id: ids).index_by(&:id)
    end
  end
end
