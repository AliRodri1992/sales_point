# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :organization, inverse_of: :subscriptions
  belongs_to :membership_plan

  has_many :subscription_events, dependent: :destroy

  enum :status,
       {
         trialing: 'trialing',
         active: 'active',
         past_due: 'past_due',
         paused: 'paused',
         canceled: 'canceled',
         expired: 'expired'
       },
       validate: true

  scope :current, -> { where(status: %w[trialing active]) }

  validates :starts_at, presence: true
  validates :ends_at, comparison: { greater_than_or_equal_to: :starts_at }, allow_nil: true
  validates :trial_ends_at, comparison: { greater_than_or_equal_to: :starts_at }, allow_nil: true

  def active_or_trialing?
    active? || trialing?
  end

  def trial?
    trialing? && trial_ends_at.present?
  end

  def trial_expired?
    trial? && trial_ends_at <= Time.current
  end

  def trial_days_remaining
    return 0 unless trial?

    [((trial_ends_at - Time.current) / 1.day).ceil, 0].max
  end

  def feature_enabled?(key)
    plan_feature = membership_plan.membership_plan_features
                                  .joins(:membership_feature)
                                  .find_by(membership_features: { key: key })
    plan_feature&.enabled?
  end

  def limit_for(key)
    feature = membership_plan.membership_plan_features
                             .joins(:membership_feature)
                             .find_by(membership_features: { key: key })
    feature&.limit
  end

  def unlimited?(key)
    feature = membership_plan.membership_plan_features
                             .joins(:membership_feature)
                             .find_by(membership_features: { key: key })
    feature&.value == 'unlimited'
  end

  def limit_reached?(key, current_count)
    return false if unlimited?(key)

    limit = limit_for(key)
    limit.present? && current_count >= limit
  end
end
