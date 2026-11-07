# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Note, type: :model do
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization:) }

  it 'creates a polymorphic note for a legacy notes write without duplicating the record' do
    branch.update!(notes: 'First note')

    expect(branch.note_entries.count).to eq(1)
    expect(branch.note_entries.first).to have_attributes(
      notable: branch, organization:, kind: 'general', body: 'First note'
    )

    branch.update!(notes: 'Revised note')
    expect(branch.note_entries.count).to eq(1)
    expect(branch.reload.note_body).to eq('Revised note')
    expect(branch.note_entries.first.reload.body).to eq('Revised note')
  end

  it 'clears the corresponding polymorphic note when the form clears the value' do
    branch.update!(notes: 'Remove this')
    branch.update!(notes: '')

    expect(branch.note_entries.general).to be_empty
    expect(branch.reload.note_body).to be_nil
  end

  it 'uses the unsaved field value when displaying a form with validation errors' do
    branch.update!(notes: 'Saved')
    branch.assign_attributes(notes: 'Unsaved edit')

    expect(branch.note_body).to eq('Unsaved edit')
    expect(branch.note_entries.first.body).to eq('Saved')
  end

  it 'returns the polymorphic note as the authoritative form value' do
    branch.update!(notes: 'Stored in notes')
    branch.note_entries.general.sole.update!(body: 'Polymorphic authoritative')

    expect(branch.reload.note_body).to eq('Polymorphic authoritative')
  end

  it 'supports the same note relationship for records without an organization' do
    client = create(:client, notes: 'Client note')

    expect(client.note_entries.general.first).to have_attributes(
      notable: client, organization: nil, body: 'Client note'
    )
  end

  it 'rejects a note linked to another organization' do
    note = described_class.new(notable: branch, organization: create(:organization),
                               kind: 'general', body: 'Wrong organization')

    expect(note).not_to be_valid
    expect(note.errors[:organization]).to be_present
  end

  it 'enforces one general note per record and requires nonempty content' do
    branch.update!(notes: 'Existing')
    duplicate = described_class.new(notable: branch, organization:, kind: 'general', body: 'Another')
    empty = described_class.new(notable: branch, organization:, kind: 'general', body: '')

    expect(empty).not_to be_valid
    expect do
      described_class.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
