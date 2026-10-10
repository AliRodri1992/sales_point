import { Controller } from "@hotwired/stimulus"
import intlTelInput from "intl-tel-input"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.ready = false
    this.inputTarget.dataset.valid = "false"
    this.inputTarget.setAttribute("aria-invalid", "false")

    this.iti = intlTelInput(this.inputTarget, {
      initialCountry: "mx",
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
    this.updateValidity()
  }

  updateValidity = () => {
    if (!this.ready) return

    this.inputTarget.dataset.valid = this.iti.isValidNumber() ? "true" : "false"
  }
}
