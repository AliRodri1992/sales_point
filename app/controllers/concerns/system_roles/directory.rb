# frozen_string_literal: true

module SystemRoles
  module Directory
    private

    def load_directory
      load_directory_filters
      load_directory_records
      load_directory_metrics
      @new_system_role = SystemRole.new(status: :inactive, role_type: :system) if policy(SystemRole).create?
    end

    def load_directory_filters
      @archived = params[:filter] == 'archived'
      @role_search = params[:search].to_s.strip.slice(0, 100)
      @role_type = params[:role_type].presence_in(%w[system branch])
      @role_sort = params[:sort].presence_in(%w[name code recent]) || 'name'
    end

    def load_directory_records
      scope = @archived ? SystemRole.deprecated : SystemRole.available
      @system_roles = paginate_table_listing(sort_directory(filter_directory(scope)), table_key: 'system_roles')
    end

    def load_directory_metrics
      @role_metrics = {
        total: SystemRole.available.count + SystemRole.deprecated.count,
        active: SystemRole.available.active.count,
        protected: SystemRole.available.where(code: SystemRole::ADMINISTRATIVE_CODES).count,
        archived: SystemRole.deprecated.count
      }
    end

    def filter_directory(scope)
      scope = scope.where(role_type: @role_type) if @role_type
      return scope if @role_search.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@role_search)}%"
      scope.where(
        'system_roles.name ILIKE :pattern OR system_roles.code ILIKE :pattern ' \
        'OR system_roles.description ILIKE :pattern', pattern:
      )
    end

    def sort_directory(scope)
      case @role_sort
      when 'code' then scope.order(:code, :id)
      when 'recent' then scope.order(updated_at: :desc, id: :desc)
      else scope.order(:name, :id)
      end
    end
  end
end
