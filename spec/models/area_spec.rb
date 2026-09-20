require 'rails_helper'

RSpec.describe Area, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      area = build(:area)
      expect(area).to be_valid
    end

    it 'requires a name' do
      area = build(:area, name: nil)
      expect(area).not_to be_valid
      expect(area.errors[:name]).to include("can't be blank")
    end

    it 'requires a code' do
      area = build(:area, code: nil)
      expect(area).not_to be_valid
      expect(area.errors[:code]).to include("can't be blank")
    end

    it 'requires a unique code' do
      create(:area, code: 'cashier')
      area = build(:area, code: 'cashier')
      expect(area).not_to be_valid
      expect(area.errors[:code]).to include('has already been taken')
    end

    it 'requires code to match lowercase alphanumeric format' do
      area = build(:area, code: 'Invalid-Code!')
      expect(area).not_to be_valid
      expect(area.errors[:code]).to include('is invalid')
    end

    it 'requires code to be at most 20 characters' do
      area = build(:area, code: 'a' * 21)
      expect(area).not_to be_valid
      expect(area.errors[:code]).to include('is too long (maximum 20 characters)')
    end
  end

  describe 'defaults' do
    it 'defaults new records to active status' do
      area = Area.new(name: 'Test', code: 'test')
      expect(area.status).to eq('active')
    end

    it 'does not override an explicitly set status' do
      area = Area.new(name: 'Test', code: 'test', status: 'inactive')
      expect(area.status).to eq('inactive')
    end
  end

  describe 'scopes' do
    before do
      create_list(:area, 2, status: 'active')
      create_list(:area, 1, status: 'inactive')
      create(:area, deleted_at: Time.current)
    end

    it 'available returns active areas' do
      expect(Area.available.count).to eq(2)
    end

    it 'not_deleted excludes soft-deleted areas' do
      expect(Area.not_deleted.count).to eq(3)
    end
  end
end
