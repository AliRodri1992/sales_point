# frozen_string_literal: true

module Users
  module StatusTransitionValidations
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Validations

      validates :reason, presence: true, length: { maximum: 1000 }
      validates :resolution, presence: true, length: { maximum: 1000 }, if: :resolution_required?
      validate :future_review_date, if: :review_date_supplied?
    end

    private

    def resolution_required?
      @target != 'deleted' && @user.organization_memberships.active.exists?(
        organization: @organization, account_status: 'blocked'
      )
    end

    def review_date_supplied?
      @target == 'suspended' && @review_at.present?
    end

    def future_review_date
      parsed = Time.zone.parse(@review_at.to_s)
      return if parsed&.future?

      errors.add(:review_at, I18n.t('user_status_form.review_date_future'))
    rescue ArgumentError, TypeError
      errors.add(:review_at, I18n.t('user_status_form.review_date_future'))
    end
  end
end
