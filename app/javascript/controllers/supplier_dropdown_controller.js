import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "label", "value"]

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
    const option = event.currentTarget
    if (this.hasValueTarget && option.matches("button[data-option-value]")) {
      this.valueTarget.value = option.dataset.optionValue
      this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
      this.labelTarget.textContent = option.querySelector("[data-option-label]").textContent.trim()
      this.element.querySelectorAll("button[data-option-value]").forEach((button) => {
        button.setAttribute("aria-selected", String(button === option))
      })
      this.close()
      return
    }

    const input = option.closest("label")?.querySelector("input")
    if (!input) return

    event.preventDefault()
    input.checked = true
    input.dispatchEvent(new Event("change", { bubbles: true }))
    this.labelTarget.textContent = option.querySelector("[data-option-label]").textContent.trim()
    this.close()
  }

  close() {
    this.element.open = false
  }
}
