module PaginationHelper
  def pagination_links(total_pages, frame: nil, window: nil)
    return '' if total_pages <= 1

    current_page = (params[:page] || 1).to_i.clamp(1, total_pages)

    links = []
    links << prev_link(current_page, frame:) if current_page > 1
    links.concat(window ? windowed_page_links(current_page, total_pages, frame:, window:) :
                           page_links(current_page, total_pages, frame:))
    links << next_link(current_page, total_pages, frame:) if current_page < total_pages

    safe_join(links, ' ')
  end

  def prev_link(current_page, frame: nil)
    label = t('admin.pagination.prev')
    pagination_link(label, current_page - 1, current_page <= 1, frame:)
  end

  def next_link(current_page, total_pages, frame: nil)
    label = t('admin.pagination.next')
    pagination_link(label, current_page + 1, current_page >= total_pages, frame:)
  end

  def page_links(current_page, total_pages, frame: nil)
    (1..total_pages).map do |page|
      if page == current_page
        active_link(page.to_s)
      else
        pagination_link(page.to_s, page, false, frame:)
      end
    end
  end

  def windowed_page_links(current_page, total_pages, frame:, window:)
    pages = ([1, total_pages] + ((current_page - window)..(current_page + window)).to_a)
            .select { |page| page.between?(1, total_pages) }.uniq.sort
    pages.each_with_object([]) do |page, result|
      if result.any? && page > result.last[:page] + 1
        result << { page: page - 1, html: tag.span('…', class: 'px-1 text-slate-400', aria: { hidden: true }) }
      end
      item = page == current_page ? active_link(page.to_s) : pagination_link(page.to_s, page, false, frame:)
      result << { page:, html: item }
    end.pluck(:html)
  end

  def active_link(label)
    tag.span(label,
             class: 'px-3 py-1 text-sm rounded-lg border border-emerald-600 bg-emerald-600 ' \
                    'font-semibold text-white cursor-default',
             aria: { current: 'page' })
  end

  def pagination_link(label, page, disabled, frame: nil)
    base = 'px-3 py-1 text-sm rounded-lg border transition '

    if disabled
      tag.span(label, class: "#{base}border-slate-200 text-slate-400 cursor-default",
                      aria: { disabled: true })
    else
      styles = "#{base}border-slate-300 text-slate-700 hover:border-emerald-500 " \
               "'hover:bg-emerald-50 hover:text-emerald-700 focus-visible:outline '" \
               'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600'
      link_to(url_for(request.query_parameters.merge(page: page)),
              class: styles,
              data: frame ? { turbo_frame: frame } : nil) do
        label
      end
    end
  end
end
