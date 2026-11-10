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
            uniqueness: { case_sensitive: false, conditions: -> { where(deleted_at: nil) } },
            format: { with: /\A[a-z]{2}\z/ },
            length: { maximum: 2 }

  validates :name,
            presence: true,
            length: { maximum: 100 }

  validate :supported_locale_if_active
  validate :code_is_immutable, on: :update
  validate :protect_default_locale

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

  # New languages are active by default; only configured locales can be active.
  after_initialize :set_default_status, if: :new_record?
  after_commit :invalidate_translation_cache

  scope :available, lambda {
    where(status: :active, deleted_at: nil)
  }

  scope :selectable, -> { available.where(code: I18n.available_locales.map(&:to_s)) }

  scope :not_deleted, lambda {
    where(deleted_at: nil)
  }

  # Restore the archived row rather than creating another language ID.
  # Keeping the ID preserves its translations and references from other tables.
  def self.restore_retired(candidate)
    transaction do
      archived = where(code: candidate.code).where.not(deleted_at: nil).order(:id).lock.first
      next unless archived

      archived.assign_attributes(name: candidate.name, flag_iso: candidate.flag_iso,
                                 status: candidate.status, deleted_at: nil)
      if archived.save
        archived
      else
        candidate.errors.merge!(archived.errors)
        false
      end
    end
  end

  def flag_url(_size = '64x48')
    path = "flags/#{flag_iso.to_s.downcase}.svg"
    path = 'flags/unknown.svg' unless Rails.root.join('app/assets/images', path).file?
    ActionController::Base.helpers.image_path(path)
  end

  def flag_srcset = "#{flag_url} 1x"

  private

  def supported_locale_if_active
    return unless active? && code.present?
    return if I18n.available_locales.map(&:to_s).include?(code)

    errors.add(:code, I18n.t('admin.languages.validation.unsupported_locale'))
  end

  def code_is_immutable
    return unless will_save_change_to_code?

    errors.add(:code, I18n.t('admin.languages.validation.immutable_code'))
  end

  def protect_default_locale
    return unless code == I18n.default_locale.to_s
    return if active? && deleted_at.nil?

    errors.add(:base, I18n.t('admin.languages.validation.default_required'))
  end

  def invalidate_translation_cache
    Translate.invalidate_cache!
  end

  def set_default_status
    self.status ||= 'active'
  end
end
