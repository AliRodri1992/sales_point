import { Controller } from "@hotwired/stimulus"
import intlTelInput from "intl-tel-input"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.ready = false
    this.inputTarget.dataset.valid = "false"
    this.inputTarget.setAttribute("aria-invalid", "false")

    const storedCountry = this.inputTarget.dataset.countryCode?.toLowerCase()
    const initialCountry = /^[a-z]{2}$/.test(storedCountry || "") ? storedCountry : "mx"
    this.iti = intlTelInput(this.inputTarget, {
      initialCountry,
      separateDialCode: true,
      showFlags: true,
      countrySelectorMode: "AUTO",
      countrySearch: true,
      strictMode: true,
      formatAsYouType: true,
      numberDisplayFormat: "INTERNATIONAL",
      loadUtils: () => import("intl-tel-input/utils"),
      countryNameLocale: document.documentElement.lang || "es"
    })

    this.iti.promise.then(() => {
      this.ready = true
      this.syncCountryCode()
      this.updateValidity()
    })

    this.form = this.inputTarget.form
    this.form?.addEventListener("submit", this.normalizeOnSubmit)
    this.inputTarget.addEventListener("input", this.updateValidity)
    this.inputTarget.addEventListener("blur", this.updateValidity)
    this.inputTarget.addEventListener("countrychange", this.handleCountryChange)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.normalizeOnSubmit)
    this.inputTarget.removeEventListener("input", this.updateValidity)
    this.inputTarget.removeEventListener("blur", this.updateValidity)
    this.inputTarget.removeEventListener("countrychange", this.handleCountryChange)
    this.iti?.destroy()
  }

  normalizeOnSubmit = () => {
    if (this.ready && this.iti.isValidNumber()) {
      this.inputTarget.value = this.iti.getNumber()
    }
  }

  handleCountryChange = () => {
    this.syncCountryCode()
    this.updateValidity()
  }

  syncCountryCode = () => {
    const name = this.inputTarget.name.replace(/\[number\]$/, "[country_code]")
    if (name === this.inputTarget.name) return

    const selectedCode = this.iti.getSelectedCountryData()?.iso2?.toUpperCase()
    if (!selectedCode) return

    let field = Array.from(this.form?.querySelectorAll('input[name]') || [])
      .find((input) => input.name === name)
    if (!field) {
      field = document.createElement("input")
      field.type = "hidden"
      field.name = name
      this.element.append(field)
    }
    field.value = selectedCode
  }

  updateValidity = () => {
    if (!this.ready) return

    const hasValue = this.inputTarget.value.trim().length > 0
    const valid = this.iti.isValidNumber()
    this.inputTarget.dataset.valid = valid ? "true" : "false"
    this.inputTarget.setAttribute("aria-invalid", String(hasValue && !valid))
    this.inputTarget.classList.toggle("border-rose-500", hasValue && !valid)
    this.inputTarget.classList.toggle("bg-rose-50", hasValue && !valid)
  }
}
