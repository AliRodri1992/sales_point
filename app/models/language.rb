# frozen_string_literal: true

class Language < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :translates, dependent: :nullify
  has_many :translation_generations, dependent: :nullify
  has_many :source_translation_generations,
           class_name: 'TranslationGeneration',
           foreign_key: :source_language_id,
           inverse_of: :source_language,
           dependent: :nullify

  validates :code, presence: true, uniqueness: true, length: { maximum: 2 }
  validates :locale, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :name, presence: true
  validates :flag_iso, presence: true, length: { is: 2 }

  validate :code_change_does_not_repurpose_translations, on: :update

  enum :status,
       { active: 'active', inactive: 'inactive' },
       validate: true

  after_initialize :set_default_status, if: :new_record?
  before_validation :set_default_locale, if: -> { locale.blank? || will_save_change_to_code? }

  scope :available, -> { where(status: :active, deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  def flag_url(size = '64x48')
    "https://flagcdn.com/#{size}/#{flag_iso}.png"
  end

  def flag_srcset
    ["#{flag_url('80x60')} 2x", "#{flag_url('96x72')} 3x"].join(', ')
  end

  private

  def set_default_status
    self.status ||= 'active'
  end

  def set_default_locale
    self.locale = code
  end

  def code_change_does_not_repurpose_translations
    return unless will_save_change_to_code?
    return unless translates.exists?

    errors.add(:code, 'cannot change when translations already exist')
  end
end
