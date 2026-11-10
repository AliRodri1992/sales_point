import { Controller } from "@hotwired/stimulus"

// Search and status share one form. Native GET submission remains available without JS.
export default class extends Controller {
  static values = { delay: { type: Number, default: 350 } }

  connect() {
    this.timeoutId = null
    this.composing = false
  }

  beginComposition() {
    this.composing = true
    clearTimeout(this.timeoutId)
  }

  endComposition() {
    this.composing = false
    this.schedule()
  }

  debouncedSubmit(event) {
    if (this.composing || event?.isComposing) return
    this.schedule()
  }

  submitNow() {
    clearTimeout(this.timeoutId)
    this.element.requestSubmit()
  }

  schedule() {
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeoutId)
  }
}
