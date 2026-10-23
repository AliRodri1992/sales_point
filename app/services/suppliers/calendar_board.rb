# frozen_string_literal: true

module Suppliers
  class CalendarBoard
    attr_reader :month, :view, :focus_date, :start_date, :end_date, :branch_id, :kind, :schedules, :events

    def initialize(supplier:, month: nil, view: nil, day: nil, branch_id: nil, kind: nil)
      @supplier = supplier
      @month = valid_date(month&.to_s&.match?(/\A\d{4}-\d{2}\z/) ? "#{month}-01" : nil) ||
               Date.current.beginning_of_month
      @view = view == 'week' ? 'week' : 'month'
      @focus_date = valid_date(day) || (@month == Date.current.beginning_of_month ? Date.current : @month)
      @branch_id = branch_id.to_s.match?(/\A[1-9]\d*\z/) ? branch_id.to_i : nil
      @kind = SupplierEvent::KINDS.include?(kind) ? kind : nil
      @start_date = @view == 'week' ? @focus_date.beginning_of_week(:monday) : @month.beginning_of_week(:monday)
      @end_date = @view == 'week' ? @start_date + 6 : @month.end_of_month.end_of_week(:sunday)
      load_entries
    end

    def weeks
      (@start_date..@end_date).each_slice(7).to_a
    end

    def items_on(date)
      return [] unless date.between?(@start_date, @end_date)

      weekly = @schedules.filter_map do |schedule|
        next unless schedule.weekday == date.wday
        next if excepted?(schedule, date)

        { type: :weekly, kind: schedule.kind, title: schedule.branch.name, branch: schedule.branch.name,
          time: schedule.starts_at.strftime('%H:%M'), record: schedule }
      end
      dated = @events.filter_map do |event|
        next unless event.starts_at.in_time_zone.to_date == date

        { type: :event, kind: event.kind, title: event.title, branch: event.branch.name,
          time: event.starts_at.in_time_zone.strftime('%H:%M'), record: event }
      end
      (weekly + dated).sort_by { |entry| entry[:time] }
    end

    def exception_count
      @exceptions.size
    end

    def exceptions_on(date)
      @exceptions.select do |exception|
        date >= exception.starts_on && date <= (exception.ends_on || exception.starts_on)
      end
    end

    def next_navigation(direction)
      if @view == 'week'
        { calendar_view: 'week', calendar_day: (@focus_date + direction * 7).iso8601 }
      else
        { calendar_view: 'month', calendar_month: @month.advance(months: direction).strftime('%Y-%m') }
      end
    end

    def current_navigation
      { calendar_view: @view, calendar_month: @month.strftime('%Y-%m'), calendar_day: @focus_date.iso8601 }
    end

    def filtered_params
      { calendar_branch: @branch_id, calendar_kind: @kind }
    end

    private

    def valid_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end

    def load_entries
      @schedules = @supplier.supplier_schedules.not_deleted.includes(:branch).order(:weekday, :starts_at)
      @schedules = @schedules.where(branch_id: @branch_id) if @branch_id
      @schedules = @schedules.where(kind: @kind) if @kind
      @schedules = @schedules.to_a

      @events = @supplier.supplier_events.not_deleted.includes(:branch)
                         .where(starts_at: @start_date.in_time_zone.beginning_of_day...(@end_date + 1).in_time_zone.beginning_of_day)
                         .order(:starts_at)
      @events = @events.where(branch_id: @branch_id) if @branch_id
      @events = @events.where(kind: @kind) if @kind
      @events = @events.to_a

      @exceptions = @supplier.supplier_schedule_exceptions.where(deleted_at: nil)
                             .where(starts_on: ..@end_date)
                             .where('COALESCE(ends_on, starts_on) >= ?', @start_date)
                             .to_a
      @exceptions.select! { |exception| exception.branch_id.nil? || exception.branch_id == @branch_id } if @branch_id
    end

    def excepted?(schedule, date)
      @exceptions.any? do |exception|
        date >= exception.starts_on && date <= (exception.ends_on || exception.starts_on) &&
          (exception.branch_id.nil? || exception.branch_id == schedule.branch_id) &&
          (exception.supplier_schedule_id.nil? || exception.supplier_schedule_id == schedule.id)
      end
    end
  end
end
