import { Controller } from "@hotwired/stimulus"

// Keep the next state, its consequences and the confirmation in one form.
export default class extends Controller {
  static targets = ["status", "description", "availability", "submit"]

  connect() { this.update() }

  update() {
    const choice = this.statusTarget.selectedOptions[0]
    if (!choice) return

    const blocked = choice.dataset.blocked === "true"
    const closing = choice.value === "closed"

    this.descriptionTarget.textContent = choice.dataset.description || ""
    this.availabilityTarget.hidden = !blocked
    this.availabilityTarget.textContent = blocked ? this.element.dataset.unavailableMessage || "" : ""
    this.submitTarget.disabled = blocked
    this.submitTarget.textContent = choice.dataset.actionLabel || choice.textContent
    this.submitTarget.classList.toggle("catalog-button-primary", !closing)
    this.submitTarget.classList.toggle("border-rose-600", closing)
    this.submitTarget.classList.toggle("text-rose-700", closing)
    this.element.dataset.turboConfirm = choice.dataset.confirmation || ""
  }
}
