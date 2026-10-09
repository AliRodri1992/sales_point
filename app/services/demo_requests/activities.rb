# frozen_string_literal: true

module DemoRequests
  class Activities
    def initialize(demo_request, current_user)
      @demo_request = demo_request
      @current_user = current_user
    end

    def record_all
      record_contact if @demo_request.saved_change_to_contacted_at?
      record_follow_up if follow_up_scheduled?
      record_outcome if @demo_request.saved_change_to_demo_outcome?
      record_conversion if converted?
    end

    private

    def record_contact
      @demo_request.activities.create!(
        user: @current_user,
        action: 'contact_registered',
        details: {
          channel: @demo_request.contact_channel,
          outcome: @demo_request.contact_outcome
        }
      )
    end

    def follow_up_scheduled?
      (@demo_request.saved_change_to_next_follow_up_at? ||
       @demo_request.saved_change_to_next_action?) &&
        @demo_request.next_follow_up_at.present?
    end

    def record_follow_up
      @demo_request.activities.create!(
        user: @current_user,
        action: 'follow_up_scheduled',
        details: {
          date: @demo_request.next_follow_up_at,
          action: @demo_request.next_action
        }
      )
    end

    def record_outcome
      @demo_request.activities.create!(
        user: @current_user,
        action: 'demo_outcome_recorded',
        details: {
          outcome: @demo_request.demo_outcome
        }
      )
    end

    def converted?
      @demo_request.saved_change_to_status? && @demo_request.converted?
    end

    def record_conversion
      @demo_request.activities.create!(
        user: @current_user,
        action: 'converted',
        details: {}
      )
    end
  end
end
