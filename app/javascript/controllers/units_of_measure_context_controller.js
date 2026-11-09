import { Controller } from "@hotwired/stimulus"

// Keep the frame's actual filters, sort and page during Turbo modal submissions.
// The header's URL may be older than the frame after a partial GET navigation.
export default class extends Controller {
  static queryFields = ["search", "status", "fractional", "sat_unit_key_id", "sat_health",
    "sort", "direction", "page", "per_page"]

  connect() {
    if (!this.element.hasAttribute("data-list-query")) return
    if (window.location.pathname !== "/admin/units_of_measure") return

    // Turbo Streams refresh the list without navigating. Keep the URL and
    // its history entry consistent with the effective (possibly clamped) page.
    const query = new URLSearchParams(this.element.dataset.listQuery || "")
    const url = new URL(window.location.href)
    this.constructor.queryFields.forEach((field) => {
      url.searchParams.delete(field)
      if (query.has(field)) url.searchParams.set(field, query.get(field))
    })

    if (url.href !== window.location.href) {
      window.history.replaceState(window.history.state, "", url.href)
    }
  }

  preserve(event) {
    const list = document.querySelector("#units_of_measure_list [data-list-query]")
    if (!list) return

    const context = new URLSearchParams(list.dataset.listQuery || "")
    const url = new URL(event.currentTarget.action, window.location.href)
    this.constructor.queryFields.forEach((field) => {
      url.searchParams.delete(field)
      if (context.has(field)) url.searchParams.set(field, context.get(field))
    })

    event.currentTarget.action = url.toString()
  }
}
