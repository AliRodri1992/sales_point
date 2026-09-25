import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  perPageChanged(event) {
    const url = new URL(window.location)

    url.searchParams.set("per_page", event.target.value)
    url.searchParams.set("page", "1")

    Turbo.visit(url.toString())
  }
}
