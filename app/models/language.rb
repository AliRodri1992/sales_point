# frozen_string_literal: true

class Language < ApplicationRecord
  has_many :users,
           dependent: :nullify
  has_many :translates,
           dependent: :destroy

  normalizes :code, with: ->(value) { value.strip.downcase }
  normalizes :flag_iso, with: ->(value) { value.strip.downcase }
  normalizes :name, with: ->(value) { value.strip }

  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: /\A[a-z]{2}\z/ },
            length: { maximum: 2 }

  validates :name,
            presence: true

  validates :flag_iso,
            presence: true,
            length: { is: 2 },
            format: { with: /\A[a-z]{2}\z/ }

  enum :status,
       {
         active: 'active',
         inactive: 'inactive'
       },
       validate: true

  # New languages always default to "active" so the status field doesn't
  # need to be exposed on the create form.
  after_initialize :set_default_status, if: :new_record?

  scope :available, lambda {
    where(status: :active, deleted_at: nil)
  }

  scope :selectable, -> { available.where(code: I18n.available_locales.map(&:to_s)) }

  scope :not_deleted, lambda {
    where(deleted_at: nil)
  }

  def flag_url(_size = '64x48')
    path = "flags/#{flag_iso.to_s.downcase}.svg"
    path = 'flags/unknown.svg' unless Rails.root.join('app/assets/images', path).file?
    ActionController::Base.helpers.image_path(path)
  end

  def flag_srcset = "#{flag_url} 1x"

  private

  def set_default_status
    self.status ||= 'active'
  end
end
