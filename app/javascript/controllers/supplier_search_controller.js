import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.pending = null
  }

  disconnect() {
    window.clearTimeout(this.pending)
  }

  schedule() {
    window.clearTimeout(this.pending)
    this.pending = window.setTimeout(() => this.element.requestSubmit(), 350)
  }

  submit() {
    window.clearTimeout(this.pending)
  }
}
