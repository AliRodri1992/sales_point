import { Controller } from "@hotwired/stimulus"

// Visual requirements reflect the country rules in Addresses::CountryRules.
// Inputs remain editable; the Address model owns the actual validation.
export default class extends Controller {
  connect() { this.update() }

  update() {
    const country = this.element.querySelector('[name$="[country_id]"]')
    const code = country?.selectedOptions[0]?.dataset.countryCode || "MX"
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
    this.element.querySelectorAll("[data-country-postal-wrapper]").forEach((field) => {
      field.classList.toggle("hidden", !postalRequired)
    })
  }
}
