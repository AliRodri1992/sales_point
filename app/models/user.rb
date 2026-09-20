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

  def display_name
    username.presence || initials
  end

  def notifications
    messages_relation = Noticed::Notification
                        .where(recipient: self)
                        .joins(:event)
                        .where(noticed_events: { record_type: 'Message', record_id: Message.select(:id) })

    languages_relation = Noticed::Notification
                         .where(recipient: self)
                         .joins(:event)
                         .where(noticed_events: { record_type: 'Language', record_id: Language.select(:id) })

    messages_relation
      .or(languages_relation)
      .order(Arel.sql('read_at IS NULL').desc, created_at: :desc)
  end

  def unread_notifications
    notifications.unread
  end

  def message_notifications_for(conversation)
    notifications
      .where(noticed_events: { record_type: 'Message', record_id: conversation.messages.select(:id) })
  end

  # Replaces badge, list and header live for every open tab of this user.
  def broadcast_notifications_refresh
    %w[notifications_badge notifications_list notifications_header].each do |target|
      Turbo::StreamsChannel.broadcast_replace_to(
        "notifications_#{id}",
        target: target,
        partial: "admin/shared/#{target}",
        locals: { user: self }
      )
    end
  end

  def online?
    self.class.online_user_ids.include?(id)
  end

  def self.online_user_ids
    Kredis.set(ONLINE_USERS_KEY).members.map(&:to_i)
  end
end
