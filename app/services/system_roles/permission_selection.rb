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
      return true unless missing_base_access?(selected)

      @error_key = :access_required
      false
    end

    private

    def missing_base_access?(selected)
      selected.any? { |code| dependent_access_missing?(code, selected) }
    end

    def dependent_access_missing?(code, selected)
      prefix, action = code.split('.', 2)
      return false if action.blank? || action == 'access' || DEPENDENT_PREFIXES.exclude?(prefix)

      access = "#{prefix}.access"
      selected.exclude?(access)
    end
  end
end
