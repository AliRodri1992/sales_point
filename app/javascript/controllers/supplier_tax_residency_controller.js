import { Controller } from "@hotwired/stimulus"

// Fiscal residence is determined by the primary fiscal address, not the UI locale.
export default class extends Controller {
  static targets = ["mexican", "foreign", "regime"]

  connect() {
    this.update()
  }

  update() {
    const country = this.element.querySelector('[name$="[country_id]"]')
    const code = country?.selectedOptions[0]?.dataset.countryCode
    const foreign = Boolean(code && code !== "MX")
    const rfc = this.element.querySelector('input[name="supplier[rfc]"]')
    const foreignId = this.element.querySelector('input[name="supplier[foreign_tax_id]"]')
    const regime = this.element.querySelector('select[name="supplier[sat_fiscal_regime_id]"]')
    const personType = this.element.querySelector('select[name="supplier[person_type]"]')?.value

    this.mexicanTarget.classList.toggle("hidden", foreign)
    this.foreignTarget.classList.toggle("hidden", !foreign)
    this.regimeTarget.classList.toggle("hidden", foreign)
    if (rfc) rfc.required = !foreign
    if (foreignId) foreignId.required = foreign
    if (!regime) return

    regime.disabled = foreign
    Array.from(regime.options).forEach((option) => {
      if (option.value) option.disabled = Boolean(personType && option.dataset.personType !==
        (personType === "individual" ? "F" : "M"))
    })
    if (!foreign && regime.selectedOptions[0]?.disabled) regime.value = ""
  }
}
