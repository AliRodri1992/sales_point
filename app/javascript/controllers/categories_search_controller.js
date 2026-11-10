import { Controller } from "@hotwired/stimulus"

// Keep the search responsive without submitting the form on every keystroke.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.timeoutId = null
  }

  debouncedSubmit() {
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => this.submitNow(), this.delayValue)
  }

  submitNow() {
    clearTimeout(this.timeoutId)
    this.element.requestSubmit()
  }

  disconnect() {
    clearTimeout(this.timeoutId)
  }
}
