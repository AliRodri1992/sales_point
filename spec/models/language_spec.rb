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

    it 'requires code to be at most 2 characters' do
      language = build(:language, code: 'eng')
      expect(language).not_to be_valid
      expect(language.errors[:code]).to include('is too long (maximum 2 characters)')
    end

    it 'requires flag_iso to be exactly 2 characters' do
      language = build(:language, flag_iso: 'usa')
      expect(language).not_to be_valid
      expect(language.errors[:flag_iso]).to include('has an incorrect length')
    end

    it 'accepts a 2-character code and flag_iso' do
      language = build(:language, code: 'es', flag_iso: 'mx')
      expect(language).to be_valid
    end

    it 'requires a flag_iso' do
      language = build(:language, flag_iso: nil)
      expect(language).not_to be_valid
      expect(language.errors[:flag_iso]).to include("can't be blank")
    end
  end

  describe 'defaults' do
    it 'defaults new records to active status' do
      language = Language.new(name: 'Test', code: 'tt', flag_iso: 'tt')
      expect(language.status).to eq('active')
    end

    it 'does not override an explicitly set status' do
      language = Language.new(name: 'Test', code: 'tt', flag_iso: 'tt', status: 'inactive')
      expect(language.status).to eq('inactive')
    end
  end

  describe 'flag URLs' do
    let(:language) { build(:language, flag_iso: 'mx') }

    it 'returns a fingerprinted local flag asset instead of an external URL' do
      expect(language.flag_url).to include('/assets/flags/mx')
      expect(language.flag_url).not_to include('flagcdn.com')
    end

    it 'returns a density-independent local SVG source set' do
      expect(language.flag_srcset).to eq("#{language.flag_url} 1x")
    end

    it 'uses a neutral SVG for an unknown country code' do
      language.flag_iso = 'zz'
      expect(language.flag_url).to include('/assets/flags/unknown')
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
end
