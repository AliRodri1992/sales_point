# rubocop:disable-next Metrics/ModuleLength
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

    content_tag(:p, object.errors.full_messages_for(attribute).first,
                class: 'mt-1 text-xs text-rose-600')
  end

  # rubocop:disable-next Rails/HelperInstanceVariable
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength
  def breadcrumb_items
    home = { label: t('admin.breadcrumbs.home'), path: admin_dashboard_path }
    items = [home]

    case params[:controller]
    when 'admin/products'
      products_path = { label: t('admin.breadcrumbs.products'), path: admin_products_path }
      case params[:action]
      when 'new'
        items.push(products_path, { label: t('admin.products.new.title') })
      when 'edit', 'show', 'create', 'update', 'destroy'
        product_name = @product&.name || t('admin.products.edit.label')
        items.push(products_path, { label: product_name })
      else
        items.push(products_path)
      end
    when 'admin/dashboard'
      items << { label: t('admin.breadcrumbs.dashboard') }
    when 'admin/languages'
      items << { label: t('admin.breadcrumbs.languages') }
    when 'admin/categories'
      items << { label: t('admin.breadcrumbs.categories') }
    else
      items << { label: params[:controller].to_s.remove('admin/').humanize }
    end

    items
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

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

  def pagination_links(total_pages, frame: nil)
    current_page = (params[:page] || 1).to_i

    return '' if total_pages <= 1

    links = []
    links << prev_link(current_page, frame:) if current_page > 1
    links.concat(page_links(current_page, total_pages, frame:))
    links << next_link(current_page, total_pages, frame:) if current_page < total_pages

    safe_join(links, ' ')
  end

  def prev_link(current_page, frame: nil)
    label = t('admin.products.index.pagination.prev')
    pagination_link(label, current_page - 1, current_page <= 1, frame: frame)
  end

  def next_link(current_page, total_pages, frame: nil)
    label = t('admin.products.index.pagination.next')
    pagination_link(label, current_page + 1, current_page >= total_pages, frame: frame)
  end

  def page_links(current_page, total_pages, frame: nil)
    (1..total_pages).map do |page|
      pagination_link(page, page, page == current_page, frame: frame)
    end
  end

  def pagination_link(label, page, disabled, frame: nil)
    base = 'px-3 py-1 text-sm rounded-lg border transition '

    if disabled
      tag.span(label, class: "#{base}border-slate-200 text-slate-400 cursor-default")
    else
      link_to(label, url_for(request.query_parameters.merge(page: page)),
              class: "#{base}border-slate-300 text-slate-700 hover:bg-slate-100",
              data: frame ? { turbo_frame: frame } : nil)
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
