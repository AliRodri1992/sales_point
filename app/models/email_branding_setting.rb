# frozen_string_literal: true

class EmailBrandingSetting < ApplicationRecord
  belongs_to :organization, optional: true
  has_one_attached :logo

  validates :display_name, presence: true, length: { maximum: 150 }
  validates :primary_color, :secondary_color, :button_color, presence: true
  validates :primary_color, :secondary_color, :button_color,
            format: { with: /\A#[0-9a-fA-F]{6}\z/ }
  validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :support_email, length: { maximum: 254 }
  validates :support_url, :privacy_url, format: { with: %r{\Ahttps://[^\s]+\z} }, allow_blank: true
  validates :support_url, :privacy_url, length: { maximum: 2048 }
  validates :footer_text, length: { maximum: 2000 }
  validate :safe_logo
  validate :accessible_button_color
  validate :valid_https_hosts

  private

  def safe_logo
    return unless logo.attached?

    allowed = %w[image/png image/jpeg image/webp]
    valid_logo = allowed.include?(logo.blob.content_type) &&
                 logo.blob.byte_size.positive? && logo.blob.byte_size <= 2.megabytes
    errors.add(:logo, :invalid) unless valid_logo
  end

  def accessible_button_color
    return unless button_color.to_s.match?(/\A#[0-9a-fA-F]{6}\z/)

    errors.add(:button_color, :insufficient_contrast) if button_contrast_ratio < 4.5
  end

  def valid_https_hosts
    %i[support_url privacy_url].each do |attribute|
      value = public_send(attribute)
      next if value.blank?
      next unless value.start_with?('https://')

      uri = URI.parse(value)
      valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
      errors.add(attribute, :invalid) unless valid
    rescue URI::InvalidURIError
      errors.add(attribute, :invalid)
    end
  end

  def button_contrast_ratio
    channels = button_color.delete_prefix('#').scan(/../).map { |part| part.to_i(16) / 255.0 }
    linear = channels.map { |value| value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4 }
    luminance = linear.zip([0.2126, 0.7152, 0.0722]).sum { |channel, weight| channel * weight }
    1.05 / (luminance + 0.05)
  end
end
