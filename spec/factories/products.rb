FactoryBot.define do
  factory :product do
    sequence(:code) { |n| format('PROD-%03d', n) }
    sequence(:name) { |n| "Product #{n}" }
    sequence(:slug) { |n| "product-#{n}" }
    description { 'A sample product for testing.' }
    price { 25.50 }
    cost { 12.00 }
    stock { 100.000 }
    min_stock { 10.000 }
    max_stock { 500.000 }
    barcode { nil }
    sku { nil }
    image_url { nil }
    position { 0 }
    featured { false }
    view_count { 0 }
    category { nil }
    sat_unit_key { nil }
    sat_tax { nil }
    status { 'active' }
    deleted_at { nil }
  end
end
