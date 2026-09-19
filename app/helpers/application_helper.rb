module ApplicationHelper
  AVATAR_COLORS = %w[
    bg-blue-100 text-blue-600
    bg-emerald-100 text-emerald-600
    bg-amber-100 text-amber-600
    bg-rose-100 text-rose-600
    bg-violet-100 text-violet-600
    bg-cyan-100 text-cyan-600
  ].freeze

  def user_avatar(user, size: 'h-9 w-9', online_indicator: false)
    color = AVATAR_COLORS[user.id % AVATAR_COLORS.size]

    online_dot = if online_indicator && user.online?
                   tag.span(class: 'absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full ' \
                                   'border-2 border-white bg-emerald-500')
                 end

    tag.div(
      class: "relative inline-flex #{size} items-center justify-center rounded-full #{color} text-sm font-semibold",
      'data-user-id' => user.id
    ) do
      safe_join([
        tag.span(user.initials),
        online_dot
      ].compact)
    end
  end
end
