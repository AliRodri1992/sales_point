# frozen_string_literal: true

module SystemRoles
  class PermissionSelection
    attr_reader :ids

    def initialize(values)
      @values = Array(values).compact_blank.map(&:to_s)
      @ids = @values.grep(/\A[1-9]\d*\z/).map(&:to_i).uniq
    end

    def valid?
      @values.all? { |value| value.match?(/\A[1-9]\d*\z/) } &&
        Permission.available.where(id: ids).count == ids.size
    end
  end
end
