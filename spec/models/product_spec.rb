require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      product = build(:product)
      expect(product).to be_valid
    end

    it 'requires a code' do
      product = build(:product, code: nil)
      expect(product).not_to be_valid
      expect(product.errors[:code]).to include("can't be blank")
    end

    it 'requires a unique code' do
      create(:product, code: 'duplicate')
      product = build(:product, code: 'duplicate')
      expect(product).not_to be_valid
      expect(product.errors[:code]).to include('has already been taken')
    end

    it 'requires code to match alphanumeric format' do
      product = build(:product, code: 'Invalid Code!@#')
      expect(product).not_to be_valid
      expect(product.errors[:code]).to include('is invalid')
    end

    it 'requires code to be at most 50 characters' do
      product = build(:product, code: 'a' * 51)
      expect(product).not_to be_valid
      expect(product.errors[:code]).to include('is too long (maximum 50 characters)')
    end

    it 'requires a name' do
      product = build(:product, name: nil)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it 'requires name to be at most 100 characters' do
      product = build(:product, name: 'a' * 101)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include('is too long (maximum 100 characters)')
    end

    it 'requires a price' do
      product = build(:product, price: nil)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include("can't be blank")
    end

    it 'requires price to be non-negative' do
      product = build(:product, price: -1)
      expect(product).not_to be_valid
    end

    it 'requires a stock' do
      product = build(:product, stock: nil)
      expect(product).not_to be_valid
      expect(product.errors[:stock]).to include("can't be blank")
    end

    it 'requires stock to be non-negative' do
      product = build(:product, stock: -1)
      expect(product).not_to be_valid
    end

    it 'requires max_stock to be greater than or equal to min_stock' do
      product = build(:product, min_stock: 100, max_stock: 50)
      expect(product).not_to be_valid
      expect(product.errors[:max_stock]).to include('must be greater than or equal to min_stock')
    end

    it 'accepts max_stock equal to min_stock' do
      product = build(:product, min_stock: 50, max_stock: 50)
      expect(product).to be_valid
    end

    it 'allows sku to be nil' do
      product = build(:product, sku: nil)
      expect(product).to be_valid
    end

    it 'requires sku to be unique when present' do
      create(:product, sku: 'SKU-001')
      product = build(:product, sku: 'SKU-001')
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include('has already been taken')
    end

    it 'allows barcode to be nil' do
      product = build(:product, barcode: nil)
      expect(product).to be_valid
    end

    it 'requires barcode to be unique when present' do
      create(:product, barcode: '123456789012')
      product = build(:product, barcode: '123456789012')
      expect(product).not_to be_valid
      expect(product.errors[:barcode]).to include('has already been taken')
    end

    it 'allows image_url to be blank' do
      product = build(:product, image_url: nil)
      expect(product).to be_valid
    end

    it 'accepts valid slug format' do
      product = build(:product, slug: 'my-product-slug')
      expect(product).to be_valid
    end

    it 'rejects invalid slug format' do
      product = build(:product, slug: 'invalid slug')
      expect(product).not_to be_valid
    end

    it 'validates position is non-negative integer' do
      product = build(:product, position: -1)
      expect(product).not_to be_valid
    end

    it 'accepts true for featured' do
      product = build(:product, featured: true)
      expect(product).to be_valid
    end

    it 'accepts false for featured' do
      product = build(:product, featured: false)
      expect(product).to be_valid
    end

    it 'validates view_count is non-negative integer' do
      product = build(:product, view_count: -1)
      expect(product).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'defaults new records to active status' do
      product = Product.new(code: 'TEST', name: 'Test', price: 10, stock: 1)
      expect(product.status).to eq('active')
    end

    it 'does not override an explicitly set status' do
      product = Product.new(code: 'TEST', name: 'Test', price: 10, stock: 1, status: 'inactive')
      expect(product.status).to eq('inactive')
    end

    it 'defaults position to 0' do
      product = Product.new(code: 'TEST', name: 'Test', price: 10, stock: 1)
      expect(product.position).to eq(0)
    end

    it 'defaults view_count to 0' do
      product = Product.new(code: 'TEST', name: 'Test', price: 10, stock: 1)
      expect(product.view_count).to eq(0)
    end

    it 'defaults featured to false' do
      product = Product.new(code: 'TEST', name: 'Test', price: 10, stock: 1)
      expect(product.featured).to eq(false)
    end
  end

  describe 'scopes' do
    before do
      create_list(:product, 2, status: 'active')
      create_list(:product, 1, status: 'inactive')
      create(:product, deleted_at: Time.current)
    end

    it 'available returns active products' do
      expect(Product.available.count).to eq(2)
    end

    it 'not_deleted excludes soft-deleted products' do
      expect(Product.not_deleted.count).to eq(3)
    end

    it 'featured returns products with featured=true' do
      create(:product, featured: true)
      create(:product, featured: false)
      expect(Product.featured.count).to eq(1)
    end

    it 'by_slug returns product with given slug' do
      product = create(:product, slug: 'unique-slug')
      result = Product.by_slug('unique-slug')
      expect(result).to eq([product])
    end

    it 'sorted_by_position orders by position then name' do
      Product.delete_all
      p1 = create(:product, position: 2, name: 'C')
      p2 = create(:product, position: 1, name: 'A')
      p3 = create(:product, position: 1, name: 'B')
      ordered = Product.sorted_by_position.to_a
      expect(ordered).to eq([p2, p3, p1])
    end
  end

  describe '#low_stock?' do
    it 'returns true when stock is below min_stock' do
      product = build(:product, stock: 5, min_stock: 10)
      expect(product.low_stock?).to be true
    end

    it 'returns true when stock equals min_stock' do
      product = build(:product, stock: 10, min_stock: 10)
      expect(product.low_stock?).to be true
    end

    it 'returns false when stock is above min_stock' do
      product = build(:product, stock: 50, min_stock: 10)
      expect(product.low_stock?).to be false
    end

    it 'returns false when min_stock is nil' do
      product = build(:product, stock: 0, min_stock: nil)
      expect(product.low_stock?).to be false
    end

    it 'returns false when min_stock is zero' do
      product = build(:product, stock: 0, min_stock: 0)
      expect(product.low_stock?).to be false
    end
  end

  describe '#increment_view_count!' do
    it 'increments the view_count by 1' do
      product = create(:product, view_count: 5)
      product.increment_view_count!
      expect(product.reload.view_count).to eq(6)
    end
  end

  describe '#set_slug' do
    it 'generates slug from name before validation' do
      product = Product.new(code: 'TEST', name: 'My Product Name', price: 10, stock: 1)
      product.valid?
      expect(product.slug).to eq('my-product-name')
    end
  end
end
