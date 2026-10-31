# frozen_string_literal: true

# Delta POS original icon system. Each semantic icon is an authored 24x24 SVG,
# not an external library, glyph font, or a copied Heroicon asset.
module DeltaIconsHelper
  ICON_SHAPES = DeltaIconShapes::ICON_SHAPES

  # Former icon aliases and semantic variants. All resolve to an original Delta shape.
  ICON_ALIASES = {
    'info' => 'information-circle', 'exclamation-triangle' => 'exclamation-circle',
    'cog-6-tooth' => 'cog', 'cog-8-tooth' => 'cog', 'adjustments-vertical' => 'adjustments-horizontal',
    'calendar' => 'calendar-days', 'calendar-date-range' => 'calendar-days',
    'document' => 'document-text', 'document-check' => 'check-circle',
    'document-magnifying-glass' => 'magnifying-glass',
    'archive-box-arrow-down' => 'archive-box', 'archive-box-x-mark' => 'archive-box',
    'cube-transparent' => 'cube', 'chart-pie' => 'chart-bar',
    'globe-alt' => 'language', 'globe-americas' => 'language',
    'building-office' => 'building-office-2',
    'check-badge' => 'check-circle', 'shield-exclamation' => 'shield-check',
    'finger-print' => 'shield-check', 'lock-open' => 'lock-closed',
    'paper-clip' => 'document-text', 'arrow-long-left' => 'arrow-left',
    'arrow-long-right' => 'arrow-right', 'bars-2' => 'bars-3',
    'ellipsis' => 'ellipsis-horizontal', 'arrow-uturn-left' => 'arrow-left',
    'arrow-up-on-square' => 'arrow-up-tray', 'arrow-down-on-square' => 'arrow-down-tray',
    'shopping-bag' => 'building-storefront', 'currency-dollar' => 'banknotes'
  }.freeze

  def delta_icon(name, css: nil, stroke_width: 1.8, **options)
    key = name.to_s.tr('_', '-')
    shapes = delta_icon_shapes(ICON_ALIASES.fetch(key, key))
    tag.svg(**delta_icon_attributes(css, stroke_width, options)) do
      safe_join(shapes.split('|').map { |part| delta_icon_shape(part) })
    end
  end

  private

  def delta_icon_shapes(key)
    shapes = ICON_SHAPES[key]
    return shapes if shapes

    Rails.logger.warn("Delta POS SVG icon not defined: #{key}")
    ICON_SHAPES.fetch('information-circle')
  end

  def delta_icon_attributes(css, stroke_width, options)
    classes = options.delete(:class) || css || 'size-5'
    accessibility = options.delete(:aria) || { hidden: true }
    {
      viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
      stroke_width:, stroke_linecap: 'round', stroke_linejoin: 'round',
      class: classes, aria: accessibility
    }.merge(options.except(:size, :variant, :library))
  end

  def delta_icon_shape(spec)
    type, *values = spec.split(':', 2)
    case type
    when 'c'
      x, y, r = values.first.split(',')
      tag.circle(cx: x, cy: y, r: r)
    when 'r'
      x, y, width, height, radius = values.first.split(',')
      tag.rect(x:, y:, width:, height:, rx: radius)
    else
      tag.path(d: spec)
    end
  end
end
