import { Controller } from "@hotwired/stimulus"

// Live search keeps keyboard focus while Turbo updates the results frame.
export default class extends Controller {
  connect() {
    this.timer = null
  }

  disconnect() {
    window.clearTimeout(this.timer)
  }

  search(event) {
    if (event.target.name !== "q" || event.isComposing) return

    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.element.requestSubmit(), 350)
  }

  change(event) {
    if (event.target.name === "q") return

    window.clearTimeout(this.timer)
    this.element.requestSubmit()
  }
}
