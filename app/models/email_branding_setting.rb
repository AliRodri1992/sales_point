# frozen_string_literal: true

class EmailBrandingSetting < ApplicationRecord
  belongs_to :organization, optional: true
  has_one_attached :logo

  validates :display_name, presence: true
  validates :primary_color, :secondary_color, :button_color,
            format: { with: /\A#[0-9a-fA-F]{6}\z/ }
  validates :support_url, :privacy_url, format: { with: /\Ahttps:\/\// }, allow_blank: true
  validate :safe_logo

  private

  def safe_logo
    return unless logo.attached?

    allowed = %w[image/png image/jpeg image/webp]
    errors.add(:logo, :invalid) unless allowed.include?(logo.blob.content_type) &&
                                        logo.blob.byte_size <= 2.megabytes
  end
end
