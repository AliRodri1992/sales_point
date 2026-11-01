# frozen_string_literal: true

# Catalog data is separated from the seed workflow to keep both modules focused.
require_relative 'membership_catalog_data'

module MembershipCatalogExamples
  MEMBERSHIP_FEATURES = MembershipCatalogData::MEMBERSHIP_FEATURES
  MEMBERSHIP_PLANS = MembershipCatalogData::MEMBERSHIP_PLANS
  MEMBERSHIP_PLAN_CONFIGURATION = MembershipCatalogData::MEMBERSHIP_PLAN_CONFIGURATION

  def self.seed!
    seed_features!
    seed_plans!
  end

  def self.seed_features!
    MEMBERSHIP_FEATURES.each do |attributes|
      feature = MembershipFeature.find_or_initialize_by(key: attributes[:key])
      feature.assign_attributes(attributes.merge(active: true))
      feature.save!
    end
  end

  def self.seed_plans!
    MEMBERSHIP_PLANS.each do |attributes|
      plan = MembershipPlan.find_or_initialize_by(slug: attributes[:slug])
      plan.assign_attributes(attributes)
      plan.save!

      configuration = MEMBERSHIP_PLAN_CONFIGURATION.fetch(plan.slug)
      MembershipFeature.where(deleted_at: nil).find_each do |feature|
        seed_plan_feature!(plan, feature, configuration)
      end
    end
  end

  def self.seed_plan_feature!(plan, feature, configuration)
    assignment = MembershipPlanFeature.find_or_initialize_by(membership_plan: plan, membership_feature: feature)
    limit = configuration[:limits][feature.key]
    unlimited = configuration[:limits].key?(feature.key) && limit.nil?

    assignment.assign_attributes(
      enabled: configuration[:enabled].include?(feature.key),
      limit: limit,
      value: unlimited ? 'unlimited' : nil,
      position: feature.position,
      deleted_at: nil
    )
    assignment.value = 'true' if feature.value_type == 'boolean' && assignment.enabled?
    assignment.save!
  end
end
