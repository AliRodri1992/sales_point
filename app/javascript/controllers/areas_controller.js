import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Handles the per-page selector in the areas catalog table.
// When the user picks 5, 10 or 15, we update the URL query params
// preserving sort/search/status filters and reset to page 1.
export default class extends Controller {
  perPageChanged(event) {
    const perPage = event.target.value
    const url = new URL(window.location)

    url.searchParams.set("per_page", perPage)
    url.searchParams.set("page", "1")

    Turbo.visit(url.toString())
  }
}
