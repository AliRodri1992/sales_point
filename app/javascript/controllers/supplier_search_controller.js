import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.pending = null
    this.advancedPanel = this.element.querySelector("details[data-advanced-filters]")
  }

  disconnect() {
    window.clearTimeout(this.pending)
  }

  schedule(event) {
    if (event.type === "input" && !event.target.matches("input[type=search], input[type=number]")) return
    if (event.type === "change" && event.target.matches("input[type=search], input[type=number]")) return
    window.clearTimeout(this.pending)
    const delay = event.target.matches("input[type=search], input[type=number]") ? 400 : 100
    this.pending = window.setTimeout(() => this.element.requestSubmit(), delay)
  }

  submit() {
    window.clearTimeout(this.pending)
    if (this.advancedPanel) this.advancedPanel.open = false
  }
}
