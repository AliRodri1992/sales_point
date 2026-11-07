# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261107190000_create_polymorphic_notes').to_s

RSpec.describe CreatePolymorphicNotes, type: :model do
  it 'backfills existing text notes without overwriting existing polymorphic notes' do
    organization = create(:organization)
    old_branch = create(:branch, organization:)
    # A pre-migration record must be simulated without the modern synchronization callback.
    # rubocop:disable-next Rails/SkipsModelValidations
    old_branch.update_columns(notes: 'Legacy delivery details')
    existing = create(:branch, organization:, notes: 'Current note')

    expect do
      described_class.new.backfill_legacy_notes
    end.to change { Note.where(notable: old_branch).count }.from(0).to(1)

    expect(old_branch.note_entries.general.sole.body).to eq('Legacy delivery details')
    expect(existing.note_entries.general.sole.body).to eq('Current note')
  end
end
