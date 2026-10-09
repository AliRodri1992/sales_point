import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Mirrors branches_pagination_controller.js: reloads the current query with the
// selected `per_page` (resetting to page 1) so the users index list updates.
export default class extends Controller {
  perPageChanged(event) {
    const url = new URL(window.location)

    url.searchParams.set("per_page", event.target.value)
    url.searchParams.set("page", "1")

    Turbo.visit(url.toString())
  }
}
