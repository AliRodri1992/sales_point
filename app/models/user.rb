class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :session_limitable,
         :recoverable, :rememberable, :validatable, :trackable

  belongs_to :language,
             optional: true
  has_many :user_roles, dependent: :destroy
  has_many :system_roles, through: :user_roles
  has_many :dashboard_preferences, dependent: :destroy
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants
  has_many :messages, dependent: :destroy

  ONLINE_USERS_KEY = 'online_users'.freeze

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

  def admin?
    system_roles.active.exists?(code: %w[super_admin administrator])
  end

  def role?(role_code, branch: nil)
    scope = user_roles.active.joins(:system_role).where(system_roles: { code: role_code })
    scope = scope.where(branch: branch) if branch
    scope.exists?
  end

  def initials
    base = username.presence || email.to_s
    base.scan(/\b\w/).first(2).join.upcase
  end

  def online?
    self.class.online_user_ids.include?(id)
  end

  def self.online_user_ids
    Kredis.set(ONLINE_USERS_KEY).members.map(&:to_i)
  end
end
