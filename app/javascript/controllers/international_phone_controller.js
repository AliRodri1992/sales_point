import { Controller } from "@hotwired/stimulus"
import intlTelInput from "intl-tel-input"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.ready = false
    this.inputTarget.dataset.valid = "false"

    this.iti = intlTelInput(this.inputTarget, {
      initialCountry: "mx",
      separateDialCode: true,
      showFlags: false,
      countrySelectorMode: "AUTO",
      countrySearch: true,
      strictMode: true,
      formatAsYouType: true,
      numberDisplayFormat: "INTERNATIONAL",
      loadUtils: () => import("intl-tel-input/utils"),
      hiddenInputs: (telInputName) => ({
        phone: telInputName.replace(/\[phone\]$/, "[phone_full]")
      }),
      countryNameLocale: document.documentElement.lang || "es"
    })

    this.iti.promise.then(() => {
      this.ready = true
      this.updateValidity()
    })

    this.inputTarget.addEventListener("input", this.updateValidity)
    this.inputTarget.addEventListener("blur", this.updateValidity)
    this.inputTarget.addEventListener("countrychange", this.updateValidity)
  }

  disconnect() {
    this.inputTarget.removeEventListener("input", this.updateValidity)
    this.inputTarget.removeEventListener("blur", this.updateValidity)
    this.inputTarget.removeEventListener("countrychange", this.updateValidity)
    this.iti?.destroy()
  }

  updateValidity = () => {
    if (!this.ready) return

    this.inputTarget.dataset.valid = this.iti.isValidNumber() ? "true" : "false"
  }
}
