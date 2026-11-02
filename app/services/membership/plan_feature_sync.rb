# frozen_string_literal: true

module Membership
  class PlanFeatureSync
    def initialize(plan)
      @plan = plan
    end

    def call(selected_ids:, values:, limits:)
      ids = Array(selected_ids).compact_blank.map(&:to_i)
      deactivate_missing(ids)
      ids.each_with_index do |id, position|
        save_assignment(id, position, values || {}, limits || {})
      end
    end

    private

    def deactivate_missing(ids)
      @plan.membership_plan_features.where.not(membership_feature_id: ids).find_each do |assignment|
        assignment.update!(deleted_at: Time.current)
      end
    end

    def save_assignment(feature_id, position, values, limits)
      assignment = @plan.membership_plan_features.with_deleted.find_or_initialize_by(membership_feature_id: feature_id)
      assignment.assign_attributes(
        enabled: true,
        value: values[feature_id.to_s],
        limit: limits[feature_id.to_s].presence,
        position: position,
        deleted_at: nil
      )
      assignment.save!
    end
  end
end
