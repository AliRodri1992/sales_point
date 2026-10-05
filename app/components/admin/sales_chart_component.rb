# frozen_string_literal: true

module Admin
  class SalesChartComponent < ViewComponent::Base
    ChartPoint = Data.define(:label, :height, :color, :highlight)

    PERIODS = {
      '7_days' => 'admin.dashboard.widgets.sales.periods.7_days',
      '30_days' => 'admin.dashboard.widgets.sales.periods.30_days',
      'year' => 'admin.dashboard.widgets.sales.periods.year'
    }.freeze

    DAY_LABELS = {
      mon: 'admin.dashboard.widgets.sales.days.mon',
      tue: 'admin.dashboard.widgets.sales.days.tue',
      wed: 'admin.dashboard.widgets.sales.days.wed',
      thu: 'admin.dashboard.widgets.sales.days.thu',
      fri: 'admin.dashboard.widgets.sales.days.fri',
      sat: 'admin.dashboard.widgets.sales.days.sat',
      today: 'admin.dashboard.widgets.sales.days.today'
    }.freeze

    def initialize(period: '7_days', data: nil)
      super()

      @period = period
      @data = data || default_data
    end

    private

    attr_reader :period

    def periods
      PERIODS
    end

    def chart_points
      @data.map do |point|
        ChartPoint.new(
          label: point[:label],
          height: point[:height],
          color: point[:color],
          highlight: point[:highlight] || false
        )
      end
    end

    def default_data
      [
        { label: DAY_LABELS[:mon], height: 42, color: 'bg-blue-100' },
        { label: DAY_LABELS[:tue], height: 58, color: 'bg-blue-200' },
        { label: DAY_LABELS[:wed], height: 48, color: 'bg-blue-300' },
        { label: DAY_LABELS[:thu], height: 72, color: 'bg-blue-400' },
        { label: DAY_LABELS[:fri], height: 66, color: 'bg-blue-500' },
        { label: DAY_LABELS[:sat], height: 86, color: 'bg-blue-600' },
        { label: DAY_LABELS[:today], height: 100, color: 'bg-nexus-green', highlight: true }
      ]
    end
  end
end
