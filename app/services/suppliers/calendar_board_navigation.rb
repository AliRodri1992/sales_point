# frozen_string_literal: true

module Suppliers
  module CalendarBoardNavigation
    private

    def setup_navigation(options)
      @month = parse_month(options[:month])
      @view = %w[month week day].include?(options[:view]) ? options[:view] : 'month'
      @focus_date = valid_date(options[:day]) || default_focus
      @month = focus_date.beginning_of_month unless view == 'month'
      setup_range
    end

    def setup_range
      @start_date = view == 'month' ? month.beginning_of_week(:monday) : focus_date.beginning_of_week(:monday)
      @start_date = focus_date if view == 'day'
      @end_date = if view == 'month'
                    month.end_of_month.end_of_week(:monday)
                  else
                    view == 'day' ? focus_date : start_date + 6
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
  end
end
