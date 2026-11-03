class User < ApplicationRecord
  extend UserChatPresence

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :session_limitable,
         :recoverable, :rememberable, :validatable, :trackable

  # Form-only selections are validated by the admin account writer.
  # Declaring the virtual attribute lets ActiveModel format field errors.
  attr_accessor :branch_role_assignments

  belongs_to :language,
             optional: true
  belongs_to :employee, optional: true

  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  has_many :user_roles, dependent: :destroy
  has_many :system_roles, through: :user_roles
  has_many :dashboard_preferences, dependent: :destroy
  has_many :table_page_preferences, dependent: :destroy
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants
  has_many :messages, dependent: :destroy
  has_many :onboarding_audits, dependent: :restrict_with_exception
  has_many :user_invitations, dependent: :destroy
  has_many :user_security_incidents, dependent: :restrict_with_exception

  ONLINE_USERS_KEY = 'online_user_connections'.freeze

  enum :user_type,
       {
         employee: 'employee',
         customer: 'customer',
         supplier: 'supplier'
       },
       validate: true

  enum :status,
       {
         pending: 'pending',
         active: 'active',
         suspended: 'suspended',
         blocked: 'blocked',
         deleted: 'deleted'
       },
       validate: true

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            'valid_email_2/email': true

  validates :user_type,
            presence: true

  validates :status,
            presence: true

  validates :theme,
            presence: true,
            inclusion: { in: Theme.ids }

  def active_for_authentication?
    super && active? && deleted_at.nil? && organization_accessible?
  end

  def organization_accessible?
    membership_scope = organization_memberships.where(deleted_at: nil)
    return true unless membership_scope.exists?

    membership_scope.accessible.exists?
  end

  def admin?
    system_roles.active.exists?(code: %w[super_admin administrator])
  end

  def role?(role_code, branch: nil)
    scope = user_roles.active.joins(:system_role).where(system_roles: { code: role_code })
    scope = scope.where(branch: branch) if branch
    scope.exists?
  end

  def permission?(permission_code)
    user_roles.active
              .joins(system_role: :permissions)
              .exists?(permissions: { code: permission_code, status: 'active' })
  end

  def initials
    base = username.presence || email.to_s.split('@').first.to_s
    parts = base.scan(/[[:alnum:]]+/)
    return 'U' if parts.empty?
    return parts.first.to_s.first(2).upcase if parts.one?

    parts.first(2).pluck(0).join.upcase
  end

  def display_name
    username.presence || initials
  end

  def display_role_name
    @display_role_name ||= system_roles.active.order(:name).pick(:name)
  end

  def notifications
    models = [User, Message, Language, Category, Product, Branch, Client, SystemRole, Supplier, AccountPayable]
    models.drop(1).reduce(notification_relation_for(models.first)) do |relation, model|
      relation.or(notification_relation_for(model))
    end.order(Arel.sql('read_at IS NULL').desc, created_at: :desc)
  end

  def unread_notifications
    notifications.unread
  end

  def message_notifications_for(conversation)
    notifications
      .where(noticed_events: { record_type: 'Message', record_id: conversation.messages.with_deleted.select(:id) })
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

  private

  def notification_relation_for(model_class)
    record_scope = model_class.respond_to?(:with_deleted) ? model_class.with_deleted : model_class

    Noticed::Notification
      .where(recipient: self)
      .joins(:event)
      .where(noticed_events: { record_type: model_class.name,
                               record_id: record_scope.select(:id) })
  end
end
