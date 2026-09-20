import { Controller } from "@hotwired/stimulus"

// Auto-submits the areas search form as the user types, debounced,
// so results update live without needing to press Enter or click Apply.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.timeoutId = null
  }

  debouncedSubmit() {
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeoutId)
  }
}
