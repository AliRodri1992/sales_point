module PaginationHelper
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
    label = t('admin.pagination.prev')
    pagination_link(label, current_page - 1, current_page <= 1, frame:)
  end

  def next_link(current_page, total_pages, frame: nil)
    label = t('admin.pagination.next')
    pagination_link(label, current_page + 1, current_page >= total_pages, frame:)
  end

  def page_links(current_page, total_pages, frame: nil)
    (1..total_pages).map do |page|
      pagination_link(page.to_s, page, page == current_page, frame:)
    end
  end

  def pagination_link(label, page, disabled, frame: nil)
    base = 'px-3 py-1 text-sm rounded-lg border transition '

    if disabled
      tag.span(label, class: "#{base}border-slate-200 text-slate-400 cursor-default")
    else
      link_to(url_for(request.query_parameters.merge(page: page)),
              class: "#{base}border-slate-300 text-slate-700 hover:bg-slate-100",
              data: frame ? { turbo_frame: frame } : nil) do
        label
      end
    end
  end
end
