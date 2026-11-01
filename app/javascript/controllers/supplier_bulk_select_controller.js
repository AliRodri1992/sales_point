import { Controller } from "@hotwired/stimulus"

// Accessible bulk selection; no inline handlers (compatible with strict CSP).
export default class extends Controller {
  static targets = ["all", "item", "submit", "count"]

  connect() { this.refresh() }

  toggleAll() {
    this.itemTargets.forEach((item) => { if (!item.disabled) item.checked = this.allTarget.checked })
    this.refresh()
  }

  refresh() {
    const enabled = this.itemTargets.filter((item) => !item.disabled)
    const checked = enabled.filter((item) => item.checked).length
    if (this.hasAllTarget) {
      this.allTarget.checked = enabled.length > 0 && checked === enabled.length
      this.allTarget.indeterminate = checked > 0 && checked < enabled.length
    }
    if (this.hasSubmitTarget) this.submitTarget.disabled = checked === 0
    if (this.hasCountTarget) {
      const template = this.countTarget.dataset.template || "%{count}"
      this.countTarget.textContent = template.replace("%{count}", String(checked))
    }
  }
}
