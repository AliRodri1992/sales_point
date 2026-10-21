# frozen_string_literal: true

module Suppliers
  class ScheduleConflict
    def initialize(schedule)
      @schedule = schedule
    end

    def exists?
      return false unless valid_slot?

      finish = @schedule.ends_at || (@schedule.starts_at + 1.minute)
      scope.exists?([SQL, { finish:, start: @schedule.starts_at }])
    end

    private

    SQL = "starts_at < :finish AND COALESCE(ends_at, starts_at + interval '1 minute') > :start"

    def valid_slot?
      @schedule.deleted_at.nil? && @schedule.supplier_id.present? &&
        @schedule.branch_id.present? && @schedule.kind.present? &&
        !@schedule.weekday.nil? && @schedule.starts_at.present? &&
        (@schedule.ends_at.nil? || @schedule.ends_at > @schedule.starts_at)
    end

    def scope
      SupplierSchedule.not_deleted.where(
        supplier_id: @schedule.supplier_id, branch_id: @schedule.branch_id,
        kind: @schedule.kind, weekday: @schedule.weekday
      ).where.not(id: @schedule.id)
    end
  end
end
