import { Controller } from "@hotwired/stimulus"

// Keep each country's unsaved draft separate. Hidden fields are cleared so a
// previous country's information cannot be silently persisted on submit.
export default class extends Controller {
  static values = { stateRequiredCodes: Array }

  connect() {
    this.countryDrafts = new Map()
    this.previousCode = null
    this.updating = false
    this.update()
  }

  countryCode() {
    const country = this.element.querySelector('[name$="[country_id]"]')
    return country?.selectedOptions[0]?.dataset.countryCode || ""
  }

  applicable(name, code) {
    if (name === "postal_code") return !["AE", "HK", "MO", "QA"].includes(code)
    if (name === "neighborhood") return code === "MX"
    return true
  }

  addressFields() {
    return ["street", "exterior_number", "interior_number", "neighborhood",
      "city", "state", "postal_code"]
  }

  fields() {
    const result = {}
    for (const name of this.addressFields()) {
      const input = this.element.querySelector('[name$="[' + name + ']"]')
      if (input) result[name] = input
    }
    return result
  }

  rememberDraft(event) {
    if (this.updating || this.previousCode !== this.countryCode()) return
    const input = event.target
    const field = input.name?.split("[")?.at(-1)?.replace("]", "")
    if (!field || !this.addressFields().includes(field)) return

    this.countryDrafts.set(this.previousCode, {
      ...this.countryDrafts.get(this.previousCode),
      [field]: input.value
    })
  }

  switchCountry(code) {
    if (this.previousCode === code) return

    const fields = this.fields()
    if (this.previousCode !== null) {
      const draft = { ...this.countryDrafts.get(this.previousCode) }
      for (const [name, input] of Object.entries(fields)) {
        if (this.applicable(name, this.previousCode)) draft[name] = input.value
      }
      this.countryDrafts.set(this.previousCode, draft)
    }

    const restored = this.countryDrafts.get(code) || {}
    const initial = this.previousCode === null
    const changed = []
    this.updating = true
    for (const [name, input] of Object.entries(fields)) {
      const value = this.applicable(name, code) ?
        (initial ? input.value : (restored[name] ?? "")) : ""
      if (input.value === value) continue

      input.value = value
      changed.push(input)
    }
    this.previousCode = code
    this.updating = false
    changed.forEach((input) => input.dispatchEvent(new Event("input", { bubbles: true })))
  }

  update() {
    const code = this.countryCode()
    const mexico = code === "MX"
    const stateRequired = this.stateRequiredCodesValue.includes(code)
    const postalRequired = this.applicable("postal_code", code)
    this.switchCountry(code)

    const stateField = this.fields().state
    if (stateField) stateField.required = stateRequired

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
    this.element.querySelectorAll('[data-address-field="neighborhood"]').forEach((field) => {
      field.classList.toggle("hidden", !mexico)
    })
    this.element.querySelectorAll('[data-country-field="neighborhood"]').forEach((field) => {
      field.classList.toggle("hidden", !mexico)
    })
  }
}
