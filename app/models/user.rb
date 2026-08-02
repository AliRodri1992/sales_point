class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :session_limitable,
         :recoverable, :rememberable, :validatable, :trackable

  belongs_to :language,
             optional: true

  enum :user_type,
       {
         employee: 'employee',
         customer: 'customer',
         supplier: 'supplier'
       },
       validate: true

  enum :status,
       {
         active: 'active',
         suspended: 'suspended',
         blocked: 'blocked',
         deleted: 'deleted'
       },
       validate: true

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false }

  validates :user_type,
            presence: true

  validates :status,
            presence: true

  validates :theme,
            presence: true,
            inclusion: { in: Theme.ids }
end
