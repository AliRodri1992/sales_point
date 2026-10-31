require 'rails_helper'

RSpec.describe TablePagePreference, type: :model do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }

  it 'accepts the supported records per page values for each known table' do
    described_class::TABLE_KEYS.each do |key|
      preference = build(:table_page_preference, user:, organization:, table_key: key, per_page: 25)
      expect(preference).to be_valid
    end
  end

  it 'rejects unsupported table names and page sizes' do
    preference = build(:table_page_preference, user:, organization:, table_key: 'secret_table', per_page: 200)

    expect(preference).not_to be_valid
    expect(preference.errors.attribute_names).to include(:table_key, :per_page)
  end

  it 'keeps one preference per user, organization and table' do
    create(:table_page_preference, user:, organization:, table_key: 'suppliers', per_page: 5)

    duplicate = build(:table_page_preference, user:, organization:, table_key: 'suppliers', per_page: 10)
    expect(duplicate).not_to be_valid

    expect(build(:table_page_preference, user:, organization:, table_key: 'products')).to be_valid
    expect(build(:table_page_preference, user:, organization: create(:organization),
                                         table_key: 'suppliers')).to be_valid
    expect(build(:table_page_preference, user: create(:user), organization:,
                                         table_key: 'suppliers')).to be_valid
  end
  it 'soft-deletes a preference and allows the same table to be configured again' do
    original = create(:table_page_preference, user:, organization:, per_page: 5)
    original.destroy!

    expect(original.reload.deleted_at).to be_present
    expect(described_class.where(id: original.id)).to be_empty

    replacement = build(:table_page_preference, user:, organization:, per_page: 25)
    expect(replacement).to be_valid
    replacement.save!

    expect(described_class.where(user:, organization:, table_key: 'suppliers').count).to eq(1)
    expect(described_class.with_deleted.where(user:, organization:, table_key: 'suppliers').count).to eq(2)
  end

end
