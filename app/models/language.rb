# frozen_string_literal: true

class Language < ApplicationRecord
  has_many :users,
           dependent: :nullify
  has_many :translates,
           dependent: :destroy

  validates :code,
            presence: true,
            uniqueness: true

  validates :name,
            presence: true

  validates :flag_iso,
            presence: true

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
    where(status: :active)
  }

  scope :not_deleted, lambda {
    where(deleted_at: nil)
  }

  def flag_url(size = '64x48')
    "https://flagcdn.com/#{size}/#{flag_iso}.png"
  end

  def flag_srcset
    [
      "#{flag_url('80x60')} 2x",
      "#{flag_url('96x72')} 3x"
    ].join(', ')
  end

  private

  def set_default_status
    self.status ||= 'active'
  end
end
