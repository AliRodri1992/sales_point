# frozen_string_literal: true

module Suppliers
  class CalendarBoard
    attr_reader :month, :view, :focus_date, :start_date, :end_date, :selected_date, :branch_id, :kind, :schedules, :events

    def initialize(supplier:, **options)
      @supplier = supplier
      setup_navigation(options)
      setup_filters(options)
      setup_selection(options)
      load_entries
    end

    def weeks
      (start_date..end_date).each_slice(7).to_a
    end

    def items_on(date)
      return [] unless date.between?(start_date, end_date)

      (weekly_items(date) + dated_items(date)).sort_by { |item| item[:time] }
    end

    def selected_items
      items_on(selected_date)
    end

    def selected_exceptions
      exceptions_on(selected_date)
    end

    def day_navigation(date)
      filtered_params.merge(calendar_month: month.strftime('%Y-%m'), calendar_day: focus_date.iso8601,
                            calendar_view: view, calendar_selected_day: date.iso8601)
    end

    def exception_count
      @exceptions.size
    end

    def exceptions_on(date)
      @exceptions.select { |exception| includes_date?(exception, date) }
    end

    def next_navigation(direction)
      if view == 'week'
        { calendar_view: 'week', calendar_day: (focus_date + (direction * 7)).iso8601 }
      else
        { calendar_view: 'month', calendar_month: month.advance(months: direction).strftime('%Y-%m') }
      end
    end

    def filtered_params
      { calendar_branch: branch_id, calendar_kind: kind, calendar_selected_day: selected_date.iso8601 }
    end

    private

    def setup_navigation(options)
      @month = parse_month(options[:month])
      @view = options[:view] == 'week' ? 'week' : 'month'
      @focus_date = valid_date(options[:day]) || default_focus
      @start_date = view == 'week' ? focus_date.beginning_of_week(:monday) : month.beginning_of_week(:monday)
      @end_date = view == 'week' ? start_date + 6 : month.end_of_month.end_of_week(:monday)
    end

    def setup_filters(options)
      @branch_id = parse_branch(options[:branch_id])
      @kind = SupplierEvent::KINDS.include?(options[:kind]) ? options[:kind] : nil
    end

    def setup_selection(options)
      requested = valid_date(options[:selected_day])
      @selected_date = if requested&.between?(start_date, end_date)
                         requested
                       else
                         focus_date.between?(start_date, end_date) ? focus_date : start_date
                       end
    end

    def default_focus
      month == Date.current.beginning_of_month ? Date.current : month
    end

    def parse_month(value)
      return Date.current.beginning_of_month unless value.to_s.match?(/\A\d{4}-\d{2}\z/)

      valid_date("#{value}-01") || Date.current.beginning_of_month
    end

    def parse_branch(value)
      value.to_i if value.to_s.match?(/\A[1-9]\d*\z/)
    end

    def valid_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end

    def load_entries
      load_schedules
      load_dated_events
      load_exceptions
    end

    def load_schedules
      scope = @supplier.supplier_schedules.not_deleted.includes(:branch).order(:weekday, :starts_at)
      scope = scope.where(branch_id:) if branch_id
      scope = scope.where(kind:) if kind
      @schedules = scope.to_a
    end

    def load_dated_events
      range = start_date.in_time_zone.beginning_of_day...(@end_date + 1).in_time_zone.beginning_of_day
      scope = @supplier.supplier_events.not_deleted.includes(:branch).where(starts_at: range).order(:starts_at)
      scope = scope.where(branch_id:) if branch_id
      scope = scope.where(kind:) if kind
      @events = scope.to_a
    end

    def load_exceptions
      scope = @supplier.supplier_schedule_exceptions.where(deleted_at: nil)
                       .where(starts_on: ..end_date)
                       .where('COALESCE(ends_on, starts_on) >= ?', start_date)
      scope = scope.where(branch_id: [nil, branch_id]) if branch_id
      @exceptions = scope.to_a
    end

    def weekly_items(date)
      schedules.filter_map do |schedule|
        next unless schedule.weekday == date.wday
        next if excepted?(schedule, date)

        { type: :weekly, kind: schedule.kind, title: schedule.branch.name, branch: schedule.branch.name,
          time: schedule.starts_at.strftime('%H:%M'), record: schedule }
      end
    end

    def dated_items(date)
      events.filter_map do |event|
        next unless event.starts_at.in_time_zone.to_date == date

        { type: :event, kind: event.kind, title: event.title, branch: event.branch.name,
          time: event.starts_at.in_time_zone.strftime('%H:%M'), record: event }
      end
    end

    def excepted?(schedule, date)
      @exceptions.any? do |exception|
        includes_date?(exception, date) &&
          (exception.branch_id.nil? || exception.branch_id == schedule.branch_id) &&
          (exception.supplier_schedule_id.nil? || exception.supplier_schedule_id == schedule.id)
      end
    end

    def includes_date?(exception, date)
      date.between?(exception.starts_on, exception.ends_on || exception.starts_on)
    end
  end
end
