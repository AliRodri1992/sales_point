import { Controller } from "@hotwired/stimulus"

// Changing the page size is the action: there is no redundant Apply button.
// The form is targeted at _top so Turbo updates the URL and all filter controls together.
export default class extends Controller {
  apply(event) {
    if (!event.target.matches('select[name="per_page"]')) return

    this.element.requestSubmit()
  }
}
