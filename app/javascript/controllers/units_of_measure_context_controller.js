import { Controller } from "@hotwired/stimulus"

// Keep the frame's actual filters, sort and page during Turbo modal submissions.
// The header's URL may be older than the frame after a partial GET navigation.
export default class extends Controller {
  preserve(event) {
    const list = document.querySelector("#units_of_measure_list [data-list-query]")
    if (!list) return

    const context = new URLSearchParams(list.dataset.listQuery || "")
    const url = new URL(event.currentTarget.action, window.location.href)
    const fields = ["search", "status", "fractional", "sat_unit_key_id", "sat_health",
      "sort", "direction", "page", "per_page"]

    fields.forEach((field) => {
      url.searchParams.delete(field)
      if (context.has(field)) url.searchParams.set(field, context.get(field))
    })

    event.currentTarget.action = url.toString()
  }
}
