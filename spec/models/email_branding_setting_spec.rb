# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailBrandingSetting, type: :model do
  it 'validates required identity, colors and accessible button contrast' do
    setting = described_class.new(
      display_name: ' ', primary_color: 'invalid',
      secondary_color: '', button_color: '#FFFFFF'
    )
    expect(setting).not_to be_valid
    %i[display_name primary_color secondary_color button_color].each do |attribute|
      expect(setting.errors[attribute]).to be_present
    end
  end

  it 'requires HTTPS URLs with actual hosts and does not accept credentials' do
    setting = described_class.new(
      display_name: 'Shop', support_url: 'https://',
      privacy_url: 'https://user:pass@example.com/privacy'
    )
    expect(setting).not_to be_valid
    expect(setting.errors[:support_url]).to be_present
    expect(setting.errors[:privacy_url]).to be_present
  end
end
