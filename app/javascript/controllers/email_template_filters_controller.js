import { Controller } from "@hotwired/stimulus"

// Live search keeps keyboard focus while Turbo updates the results frame.
export default class extends Controller {
  static targets = ["fullPageSubmit"]

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
    if (["updated_from", "updated_to"].includes(event.target.name)) {
      this.element.requestSubmit(this.fullPageSubmitTarget)
    } else {
      this.element.requestSubmit()
    }
  }
}
