# frozen_string_literal: true

module Suppliers
  module CalendarBoardNavigation
    private

    def setup_navigation(options)
      @month = parse_month(options[:month])
      @view = options[:view] == 'week' ? 'week' : 'month'
      @focus_date = valid_date(options[:day]) || default_focus
      @month = focus_date.beginning_of_month if view == 'week'
      @start_date = view == 'week' ? focus_date.beginning_of_week(:monday) : month.beginning_of_week(:monday)
      @end_date = view == 'week' ? start_date + 6 : month.end_of_month.end_of_week(:monday)
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
  end
end
