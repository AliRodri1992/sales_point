import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "label"]

  connect() {
    this.onOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.onEscape = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this.onOutsideClick)
    document.addEventListener("keydown", this.onEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.onOutsideClick)
    document.removeEventListener("keydown", this.onEscape)
  }

  choose(event) {
    const input = event.target.closest("label")?.querySelector("input")
    if (!input) return

    input.checked = true
    this.labelTarget.textContent = event.target.closest("label").querySelector("[data-option-label]").textContent.trim()
    this.close()
  }

  close() {
    this.element.open = false
  }
}
