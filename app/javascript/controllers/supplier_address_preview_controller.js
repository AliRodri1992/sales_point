import { Controller } from "@hotwired/stimulus"

// A local, non-geocoded preview that reflects the actual submitted inputs.
// The decorative map deliberately does not imply verified coordinates.
export default class extends Controller {
  static targets = ["address", "area", "country", "purpose", "primary", "reference"]
  static values = { placeholder: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const value = (field) => this.element.querySelector('[name="address[' + field + ']"]')?.value?.trim() || ""
    const address = [value("street"), value("exterior_number"), value("interior_number")].filter(Boolean).join(" ")
    const area = [value("neighborhood"), value("city"), value("state"), value("postal_code")].filter(Boolean).join(", ")
    const select = this.element.querySelector('[name="address[country_id]"]')
    const country = select?.value ? select.selectedOptions[0]?.textContent?.trim() : ""
    const purpose = this.element.querySelector('input[name="address[purpose]"]:checked')
    const primary = this.element.querySelector('input[name="address[primary]"]:checked')
    const references = value("reference_notes")

    this.addressTarget.textContent = address || this.placeholderValue
    this.areaTarget.textContent = area
    this.countryTarget.textContent = country || ""
    this.purposeTarget.textContent = purpose?.dataset.label || "—"
    this.primaryTarget.textContent = primary?.dataset.label || "—"
    this.referenceTarget.textContent = references
    this.referenceTarget.classList.toggle("hidden", !references)
  }
}
