# frozen_string_literal: true

module SystemRoles
  class PermissionSelection
    DEPENDENT_PREFIXES = %w[languages products customers users categories].freeze

    attr_reader :ids, :error_key

    def initialize(values)
      @values = Array(values).compact_blank.map(&:to_s)
      @ids = @values.grep(/\A[1-9]\d*\z/).map(&:to_i).uniq
    end

    def valid?
      @error_key = :invalid_permissions
      return false unless @values.all? { |value| value.match?(/\A[1-9]\d*\z/) }

      selected = Permission.available.where(id: ids).pluck(:code)
      return false unless selected.size == ids.size

      available_access = Permission.available.where(
        code: DEPENDENT_PREFIXES.map { |prefix| "#{prefix}.access" }
      ).pluck(:code)
      missing = selected.filter_map do |code|
        prefix, action = code.split('.', 2)
        access = "#{prefix}.access"
        access if action.present? && action != 'access' && available_access.include?(access) &&
                  !selected.include?(access)
      end
      @error_key = :access_required if missing.any?
      missing.empty?
    end
  end
end
