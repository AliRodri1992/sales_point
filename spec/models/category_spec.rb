require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      category = build(:category)
      expect(category).to be_valid
    end

    it 'requires a name' do
      category = build(:category, name: nil)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it 'requires a code' do
      category = build(:category, code: nil)
      expect(category).not_to be_valid
      expect(category.errors[:code]).to include("can't be blank")
    end

    it 'requires a unique code' do
      create(:category, code: 'cashier')
      category = build(:category, code: 'cashier')
      expect(category).not_to be_valid
      expect(category.errors[:code]).to include('has already been taken')
    end

    it 'requires code to match lowercase alphanumeric format' do
      category = build(:category, code: 'Invalid-Code!')
      expect(category).not_to be_valid
      expect(category.errors[:code]).to include('is invalid')
    end

    it 'requires code to be at most 20 characters' do
      category = build(:category, code: 'a' * 21)
      expect(category).not_to be_valid
      expect(category.errors[:code]).to include('is too long (maximum 20 characters)')
    end
  end

  describe 'defaults' do
    it 'defaults new records to active status' do
      category = Category.new(name: 'Test', code: 'test')
      expect(category.status).to eq('active')
    end

    it 'does not override an explicitly set status' do
      category = Category.new(name: 'Test', code: 'test', status: 'inactive')
      expect(category.status).to eq('inactive')
    end
  end

  describe 'scopes' do
    before do
      create_list(:category, 2, status: 'active')
      create_list(:category, 1, status: 'inactive')
      create(:category, deleted_at: Time.current)
    end

    it 'available returns active categories' do
      expect(Category.available.count).to eq(2)
    end

    it 'not_deleted excludes soft-deleted categories' do
      expect(Category.not_deleted.count).to eq(3)
    end
  end
end
