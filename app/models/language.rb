# frozen_string_literal: true

class Language < ApplicationRecord
  has_many :users,
           dependent: :nullify

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

  scope :available, lambda {
    where(status: :active)
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
end
