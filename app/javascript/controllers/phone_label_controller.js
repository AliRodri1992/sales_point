import { Controller } from "@hotwired/stimulus"

// One optional descriptive label per phone. Presets and free text share the
// same Rails input, so editing, validation and nested-phone templates work alike.
export default class extends Controller {
  static targets = ["input", "choice", "clear"]

  connect() {
    this.sync()
  }

  select(event) {
    event.preventDefault()
    const selected = event.currentTarget.dataset.phoneLabelValue
    if (!this.hasInputTarget || !selected) return

    const current = this.inputTarget.value.trim()
    this.inputTarget.value = current.localeCompare(selected, undefined, { sensitivity: "accent" }) === 0
      ? ""
      : selected
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  clear(event) {
    event.preventDefault()
    if (!this.hasInputTarget) return

    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.inputTarget.focus()
  }

  sync() {
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value.trim()
    this.choiceTargets.forEach((choice) => {
      const selected = choice.dataset.phoneLabelValue || ""
      const active = value.length > 0 &&
        value.localeCompare(selected, undefined, { sensitivity: "accent" }) === 0
      choice.setAttribute("aria-pressed", String(active))
    })
    if (this.hasClearTarget) this.clearTarget.classList.toggle("hidden", value.length === 0)
  }
}
