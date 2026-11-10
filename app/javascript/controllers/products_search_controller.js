import { Controller } from "@hotwired/stimulus"

// Debounced catalog search; the complete GET navigation keeps filters, sorting,
// page size and browser history in sync with the address bar.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.composing = false
  }

  compositionStart() {
    this.composing = true
    clearTimeout(this.timeoutId)
  }

  compositionEnd() {
    this.composing = false
    this.debouncedSubmit()
  }

  debouncedSubmit() {
    if (this.composing) return
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeoutId)
  }
}
