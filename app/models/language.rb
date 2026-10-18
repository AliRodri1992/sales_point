# frozen_string_literal: true

class Language < ApplicationRecord
  has_many :users,
           dependent: :nullify
  has_many :translates,
           dependent: :destroy

  validates :code,
            presence: true,
            uniqueness: true,
            length: { maximum: 2 }

  validates :name,
            presence: true

  validates :flag_iso,
            presence: true,
            length: { is: 2 }

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
