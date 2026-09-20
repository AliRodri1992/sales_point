module ApplicationHelper
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
    "#{shared} #{spacing} font-medium #{color} hover:bg-slate-50 hover:text-slate-900"
  end

  def sidebar_section_open?(*controllers)
    controllers.any? { |controller| sidebar_item_active?(controller) }
  end

  def form_state_classes(object, attribute)
    object.errors[attribute].any? ? 'border border-rose-500 bg-rose-50' : 'border border-slate-200 bg-slate-50'
  end

  def error_message_for(object, attribute)
    return '' unless object.errors[attribute].any?

    content_tag(:p, object.errors[attribute].first, class: 'mt-1 text-xs text-rose-600')
  end

  def breadcrumb_items
    items = [{ label: t('admin.breadcrumbs.home'), path: admin_dashboard_path }]

    items << case params[:controller]
             when 'admin/dashboard'
               { label: t('admin.breadcrumbs.dashboard') }
             when 'admin/languages'
               { label: t('admin.breadcrumbs.languages') }
             else
               { label: params[:controller].to_s.remove('admin/').humanize }
             end

    items
  end

  def sort_link(column, title = nil)
    title ||= column.titleize
    direction = params[:sort] == column && params[:direction] != 'asc' ? 'asc' : 'desc'
    indicator = sort_indicator(column)

    link_to(
      safe_join([title, indicator]),
      url_for(request.query_parameters.merge(sort: column, direction: direction, page: nil)),
      class: 'inline-flex items-center gap-1 text-xs font-medium text-slate-500 hover:text-slate-800'
    )
  end

  def sort_indicator(column)
    return '' unless params[:sort] == column

    css = 'size-3 text-slate-800'
    if params[:direction] == 'asc'
      icon('arrow-up', class: css)
    else
      icon('arrow-down', class: css)
    end
  end

  def pagination_links(total_pages)
    current_page = (params[:page] || 1).to_i

    return '' if total_pages <= 1

    links = []
    links << prev_link(current_page) if current_page > 1
    links.concat(page_links(current_page, total_pages))
    links << next_link(current_page, total_pages) if current_page < total_pages

    safe_join(links, ' ')
  end

  def prev_link(current_page)
    label = t('admin.languages.index.pagination.prev')
    pagination_link(label, current_page - 1, current_page <= 1)
  end

  def next_link(current_page, total_pages)
    label = t('admin.languages.index.pagination.next')
    pagination_link(label, current_page + 1, current_page >= total_pages)
  end

  def page_links(current_page, total_pages)
    (1..total_pages).map do |page|
      pagination_link(page, page, page == current_page)
    end
  end

  def pagination_link(label, page, disabled)
    base = 'px-3 py-1 text-sm rounded-lg border transition '

    if disabled
      tag.span(label, class: "#{base}border-slate-200 text-slate-400 cursor-default")
    else
      link_to(label, url_for(request.query_parameters.merge(page: page)),
              class: "#{base}border-slate-300 text-slate-700 hover:bg-slate-100")
    end
  end

  def user_avatar(user, size: 'h-9 w-9', online_indicator: false)
    theme = user_avatar_theme(user)

    online_dot = if online_indicator && user.online?
                   tag.span(class: 'absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full ' \
                                   'border-2 border-white bg-emerald-500')
                 end

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
