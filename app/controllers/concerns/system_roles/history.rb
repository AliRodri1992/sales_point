# frozen_string_literal: true

module SystemRoles
  module History
    private

      def load_status_history
        scope = @system_role.status_events.includes(:actor).order(created_at: :desc, id: :desc)
        @history_pages = [(scope.count / 10.0).ceil, 1].max
        @history_page = params[:history_page].to_i.clamp(1, @history_pages)
        @status_events = scope.limit(10).offset((@history_page - 1) * 10)
      end
    
      def load_permission_history
        scope = @system_role.permission_audit_events.includes(:actor).order(created_at: :desc, id: :desc)
        @permission_history_pages = [(scope.count / 20.0).ceil, 1].max
        @permission_history_page = params[:permission_history_page].to_i.clamp(1, @permission_history_pages)
        @permission_audit_events = scope.limit(20).offset((@permission_history_page - 1) * 20)
      end
  end
end
