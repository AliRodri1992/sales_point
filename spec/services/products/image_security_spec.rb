# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product image authorization' do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  it 'binds upload tokens to their module, organization, user and validity period' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('app/assets/images/favicon-32x32.png'), 'image/png')
    blob = Products::ImageUpload.call(file:, organization:, user:)
    token = Products::ImageUpload.token(blob, organization:, user:)
    expect(Products::ImageUpload.find_signed(token, organization:, user:)).to eq(blob)
    expect(Products::ImageUpload.find_signed(blob.signed_id, organization:, user:)).to be_nil
    expect(Products::ImageUpload.find_signed(token, organization: create(:organization), user:)).to be_nil
    expect(Products::ImageUpload.find_signed(token, organization:, user: create(:user))).to be_nil
    expect(Products::ImageUpload.find_signed(token, organization: nil, user:)).to be_nil
    travel 2.days do
      expect(Products::ImageUpload.find_signed(token, organization:, user:)).to be_nil
    end
  end

  it 'also rejects invalid media types and oversized images at the model boundary' do
    product = build(:product)
    product.image.attach(io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
                         filename: 'image.svg', content_type: 'image/svg+xml')
    expect(product).not_to be_valid
    expect(product.errors[:image]).to be_present
    bytes = Rails.root.join('app/assets/images/favicon-32x32.png').binread + ('x' * 5.megabytes)
    product.image.attach(io: StringIO.new(bytes), filename: 'large.png', content_type: 'image/png')
    expect(product).not_to be_valid
    expect(product.errors[:image]).to include(I18n.t('admin.catalog_design.image_size_error'))
  end

  it 'rejects non-image content disguised with an allowed filename extension' do
    Tempfile.create(['disguised', '.jpg']) do |file|
      file.write('This is text rather than an image.')
      file.rewind
      upload = Rack::Test::UploadedFile.new(file.path, 'image/jpeg', original_filename: 'product.jpg')
      expect(Products::ImageUpload.valid?(upload)).to be(false)
    end
  end
end
