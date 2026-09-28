module ApplicationHelper
  include BreadcrumbsHelper
  include PaginationHelper

  AVATAR_COLORS = [
    { classes: 'bg-blue-100 text-blue-600', style: 'background-color:#dbeafe;color:#2563eb' },
    { classes: 'bg-emerald-100 text-emerald-600', style: 'background-color:#d1fae5;color:#059669' },
    { classes: 'bg-amber-100 text-amber-600', style: 'background-color:#fef3c7;color:#d97706' },
    { classes: 'bg-rose-100 text-rose-600', style: 'background-color:#ffe4e6;color:#e11d48' },
    { classes: 'bg-violet-100 text-violet-600', style: 'background-color:#ede9fe;color:#7c3aed' },
    { classes: 'bg-cyan-100 text-cyan-600', style: 'background-color:#cffafe;color:#0891b2' }
  ].freeze

  def user_avatar_theme(user)
    AVATAR_COLORS[user.id % AVATAR_COLORS.size]
  end

  def user_avatar_colors(user)
    user_avatar_theme(user)[:classes]
  end

  def user_avatar_style(user)
    user_avatar_theme(user)[:style]
  end

  def sidebar_item_active?(controller)
    controller_name == controller.to_s
  end

  def sidebar_link_classes(controller, variant: :default)
    active = sidebar_item_active?(controller)
    shared = 'flex items-center gap-3 rounded-xl text-sm transition'
    spacing = variant == :submenu ? 'px-3 py-2' : 'px-3 py-2.5'
    return "#{shared} #{spacing} bg-blue-50 font-semibold text-blue-600" if active

    color = variant == :submenu ? 'text-slate-500' : 'text-slate-600'
    "#{shared} #{spacing} font-medium #{color} hover:bg-slate-50 hover:text-slate-900}"
  end

  def sidebar_section_open?(*controllers)
    controllers.any? { |controller| sidebar_item_active?(controller) }
  end

  def form_state_classes(object, attribute)
    object.errors[attribute].any? ? 'border border-rose-500 bg-rose-50' : 'border border-slate-200 bg-slate-50'
  end

  def error_message_for(object, attribute)
    return '' unless object && object.errors[attribute].any?

    attribute_name = I18n.t("errors.attributes.#{attribute}", default: attribute.to_s.humanize)
    error_message = object.errors[attribute].first
    formatted_message = "#{attribute_name} #{error_message}"

    content_tag(:p, formatted_message,
                class: 'mt-1 text-xs text-rose-600')
  end

  def sort_link(column, title = nil, frame: nil)
    title ||= column.titleize
    direction = params[:sort] == column && params[:direction] != 'asc' ? 'asc' : 'desc'
    indicator = sort_indicator(column)

    link_to(
      safe_join([title, indicator]),
      url_for(request.query_parameters.merge(sort: column, direction: direction, page: nil)),
      class: 'inline-flex items-center gap-1 text-xs font-medium text-slate-500 hover:text-slate-800',
      data: frame ? { turbo_frame: frame } : nil
    )
  end

  def sort_indicator(column)
    active = params[:sort] == column
    css = active ? 'size-3 text-slate-800' : 'size-3 text-slate-300 opacity-50'

    icon(active && params[:direction] != 'asc' ? 'arrow-down' : 'arrow-up', class: css)
  end

  def user_status_badge(status)
    classes = case status
              when 'active' then 'bg-emerald-50 text-emerald-700'
              when 'suspended' then 'bg-amber-50 text-amber-700'
              when 'blocked' then 'bg-rose-50 text-rose-700'
              else 'bg-slate-100 text-slate-600'
              end
    label = t("admin.users.statuses.#{status}")
    tag.span(label, class: "inline-flex rounded-full px-2.5 py-1 text-xs font-semibold #{classes}")
  end

  def user_avatar(user, size: 'h-9 w-9', online_indicator: false)
    theme = user_avatar_theme(user)
    online_classes = 'absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-white bg-emerald-500'
    online_dot = online_indicator && user.online? ? tag.span(class: online_classes) : nil

    tag.div(
      class: "relative inline-flex #{size} items-center justify-center rounded-full text-sm font-semibold",
      style: theme[:style],
      'data-user-id' => user.id
    ) do
      safe_join([
        tag.span(user.initials),
        online_dot
      ].compact)
    end
  end
end
