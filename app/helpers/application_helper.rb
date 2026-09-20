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

  def breadcrumb_items
    items = [{ label: t('admin.breadcrumbs.home'), path: admin_dashboard_path }]

    items << case params[:controller]
             when 'admin/dashboard'
               { label: t('admin.breadcrumbs.dashboard') }
             else
               { label: params[:controller].to_s.remove('admin/').humanize }
             end

    items
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
