require 'rails_helper'

RSpec.describe Language, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      language = build(:language)
      expect(language).to be_valid
    end

    it 'requires a name' do
      language = build(:language, name: nil)
      expect(language).not_to be_valid
      expect(language.errors[:name]).to include("can't be blank")
    end

    it 'requires a code' do
      language = build(:language, code: nil)
      expect(language).not_to be_valid
      expect(language.errors[:code]).to include("can't be blank")
    end

    it 'requires a unique code' do
      create(:language, code: 'en')
      language = build(:language, code: 'en')
      expect(language).not_to be_valid
      expect(language.errors[:code]).to include('has already been taken')
    end

    it 'requires a flag_iso' do
      language = build(:language, flag_iso: nil)
      expect(language).not_to be_valid
      expect(language.errors[:flag_iso]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    before do
      create_list(:language, 2, status: 'active')
      create_list(:language, 1, status: 'inactive')
      create(:language, deleted_at: Time.current)
    end

    it 'available returns active languages' do
      expect(Language.available.count).to eq(2)
    end

    it 'not_deleted excludes soft-deleted languages' do
      expect(Language.not_deleted.count).to eq(3)
    end
  end

  describe '#flag_url' do
    it 'returns the flagcdn URL with the given size' do
      language = build(:language, flag_iso: 'us')
      expect(language.flag_url).to eq('https://flagcdn.com/64x48/us.png')
      expect(language.flag_url('80x60')).to eq('https://flagcdn.com/80x60/us.png')
    end
  end

  describe '#flag_srcset' do
    it 'returns a srcset string with multiple sizes' do
      language = build(:language, flag_iso: 'us')
      expect(language.flag_srcset).to include('80x60')
      expect(language.flag_srcset).to include('96x72')
    end
  end
end
