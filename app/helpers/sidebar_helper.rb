# frozen_string_literal: true

module SidebarHelper
  DELTA_SIDEBAR_ICONS = {
    dashboard: "M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z",
    cash_register: "M4 3h16v18H4zM8 7h8M8 11h3M8 15h3M15 11v5",
    inventory: "M12 2 2 7l10 5 10-5-10-5zM2 12l10 5 10-5M2 17l10 5 10-5",
    reports: "M4 19V9M10 19V5M16 19v-7M22 19V3",
    payments: "M2 5h20v14H2zM2 10h20M6 15h4",
    clients: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
    branches: "M3 9l9-7 9 7v11H3zM9 22V12h6v10",
    settings: "M12 15.5A3.5 3.5 0 1 0 12 8a3.5 3.5 0 0 0 0 7.5zM19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.12 2.12-.06-.06a1.7 1.7 0 0 0-1.88-.34 1.7 1.7 0 0 0-1.03 1.56V20h-3v-.08a1.7 1.7 0 0 0-1.1-1.56 1.7 1.7 0 0 0-1.88.34l-.06.06-2.12-2.12.06-.06A1.7 1.7 0 0 0 7 14.7a1.7 1.7 0 0 0-1.56-1.03H5v-3h.08A1.7 1.7 0 0 0 6.64 9.6a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.12-2.12.06.06a1.7 1.7 0 0 0 1.88.34A1.7 1.7 0 0 0 11.33 4.4V4h3v.08a1.7 1.7 0 0 0 1.03 1.56 1.7 1.7 0 0 0 1.88-.34l.06-.06 2.12 2.12-.06.06A1.7 1.7 0 0 0 19 9.3a1.7 1.7 0 0 0 1.56 1.03H21v3h-.08A1.7 1.7 0 0 0 19.4 15z"
  }.freeze

  def delta_sidebar_icon(name, class_name: "size-5")
    path = DELTA_SIDEBAR_ICONS.fetch(name.to_sym)

    content_tag(
      :svg,
      content_tag(:path, nil, d: path),
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      stroke_width: "1.7",
      stroke_linecap: "round",
      stroke_linejoin: "round",
      class: class_name,
      aria: { hidden: true }
    )
  end
end
