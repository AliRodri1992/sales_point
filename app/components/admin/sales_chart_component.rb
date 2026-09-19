# frozen_string_literal: true

module Admin
  class SalesChartComponent < ViewComponent::Base
    ChartPoint = Data.define(:label, :height, :color, :highlight)

    PERIODS = {
      '7_days' => 'Últimos 7 días',
      '30_days' => 'Últimos 30 días',
      'year' => 'Este año'
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
        { label: 'Lun', height: 42, color: 'bg-blue-100' },
        { label: 'Mar', height: 58, color: 'bg-blue-200' },
        { label: 'Mié', height: 48, color: 'bg-blue-300' },
        { label: 'Jue', height: 72, color: 'bg-blue-400' },
        { label: 'Vie', height: 66, color: 'bg-blue-500' },
        { label: 'Sáb', height: 86, color: 'bg-blue-600' },
        { label: 'Hoy', height: 100, color: 'bg-nexus-green', highlight: true }
      ]
    end
  end
end
