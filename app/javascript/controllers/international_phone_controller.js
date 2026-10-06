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
      showFlags: true,
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
      this.updateFlagEmojis()
      this.updateValidity()
    })

    this.inputTarget.addEventListener("input", this.updateValidity)
    this.inputTarget.addEventListener("blur", this.updateValidity)
    this.inputTarget.addEventListener("countrychange", this.handleCountryChange)
  }

  disconnect() {
    this.inputTarget.removeEventListener("input", this.updateValidity)
    this.inputTarget.removeEventListener("blur", this.updateValidity)
    this.inputTarget.removeEventListener("countrychange", this.handleCountryChange)
    this.iti?.destroy()
  }

  handleCountryChange = () => {
    this.updateFlagEmojis()
    this.updateValidity()
  }

  updateFlagEmojis = () => {
    const container = this.inputTarget.closest(".iti")
    if (!container) return

    container.querySelectorAll(".iti__flag").forEach((flag) => {
      const countryElement = flag.closest("[data-country-code]")
      const countryCode = countryElement?.dataset.countryCode

      if (!countryCode) return

      flag.dataset.flagEmoji = this.countryCodeToEmoji(countryCode)
    })
  }

  countryCodeToEmoji = (countryCode) => {
    return countryCode
      .toUpperCase()
      .split("")
      .map((letter) => String.fromCodePoint(127397 + letter.charCodeAt(0)))
      .join("")
  }

  updateValidity = () => {
    if (!this.ready) return

    this.inputTarget.dataset.valid = this.iti.isValidNumber() ? "true" : "false"
  }
}
