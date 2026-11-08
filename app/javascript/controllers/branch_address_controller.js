import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["country", "field"]

  connect() { this.update() }

  update() {
    const extra = this.countryTarget.selectedOptions[0]?.dataset.requiredFields || ""
    const required = new Set(["street", "city", ...extra.split(" ").filter(Boolean)])
    this.fieldTargets.forEach(field => {
      // Business rules are enforced by Address and Branch, never by HTML5.
      field.required = false
      field.setAttribute("aria-required", String(required.has(field.dataset.branchAttribute)))
    })
  }
}
