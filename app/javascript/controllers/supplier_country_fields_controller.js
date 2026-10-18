import { Controller } from "@hotwired/stimulus"

// Keep editable country-specific drafts in memory; never submit stale fields
// from a previously selected country. Address/CountryRules remain authoritative.
export default class extends Controller {
  connect() {
    this.drafts = new Map()
    this.previousCode = this.countryCode()
    this.update()
  }

  countryCode() {
    return this.element.querySelector('[name$="[country_id]"]')?.selectedOptions[0]?.dataset.countryCode || ""
  }

  countryFields() {
    return ["exterior_number", "interior_number", "neighborhood", "city", "state", "postal_code"]
  }

  field(name) {
    return this.element.querySelector('[name$="[' + name + ']"]')
  }

  update() {
    const code = this.countryCode()
    if (this.previousCode !== code) this.switchCountry(code)
    const mexico = code === "MX"
    const stateRequired = ["MX", "US", "CA", "AU", "BR", "IN"].includes(code)
    const postalRequired = !["AE", "HK", "MO", "QA"].includes(code)

    this.element.querySelectorAll("[data-country-label]").forEach((label) => {
      label.textContent = mexico ? label.dataset.countryLabelMx : label.dataset.countryLabelOther
    })
    this.element.querySelectorAll("[data-required-when]").forEach((mark) => {
      const mode = mark.dataset.requiredWhen
      const visible = mode === "always" || (mode === "mx" && mexico) ||
        (mode === "state" && stateRequired) || (mode === "postal" && postalRequired)
      mark.classList.toggle("hidden", !visible)
    })
    this.element.querySelectorAll("[data-country-postal-wrapper]").forEach((wrapper) => {
      wrapper.classList.toggle("hidden", !postalRequired)
    })
    const postal = this.field("postal_code")
    if (postal) {
      postal.disabled = !postalRequired
      if (!postalRequired) postal.value = ""
    }
  }

  switchCountry(code) {
    const previous = {}
    for (const name of this.countryFields()) {
      const input = this.field(name)
      if (input) previous[name] = input.value
    }
    if (this.previousCode) this.drafts.set(this.previousCode, previous)

    const restored = this.drafts.get(code) || {}
    for (const name of this.countryFields()) {
      const input = this.field(name)
      if (!input) continue
      const next = restored[name] || ""
      if (input.value === next) continue
      input.value = next
      input.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.previousCode = code
  }
}
