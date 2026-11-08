import { Controller } from "@hotwired/stimulus"
import intlTelInput from "intl-tel-input"
import en from "intl-tel-input/locale/en"
import es from "intl-tel-input/locale/es"
import ko from "intl-tel-input/locale/ko"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.ready = false
    this.serverInvalid = this.inputTarget.getAttribute("aria-invalid") === "true"
    this.inputTarget.dataset.phoneStatus = "loading"
    this.inputTarget.dataset.valid = "false"
    this.inputTarget.setAttribute("aria-invalid", String(this.serverInvalid))

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
      countryNameLocale: document.documentElement.lang || "es",
      uiTranslations: { en, es, ko }[document.documentElement.lang?.split("-")[0]] || en
    })

    this.iti.promise.then(() => {
      this.ready = true
      this.inputTarget.dataset.phoneStatus = "ready"
      this.syncCountryCode()
      this.updateValidity()
    }).catch(() => {
      this.inputTarget.dataset.valid = "false"
      this.inputTarget.dataset.phoneStatus = "failed"
      this.inputTarget.dispatchEvent(new CustomEvent("international-phone:validated", { bubbles: true }))
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

  normalizeOnSubmit = (event) => {
    if (!event.defaultPrevented && this.ready && this.iti.isValidNumber()) {
      this.inputTarget.value = this.iti.getNumber()
    }
  }

  handleCountryChange = (event) => {
    this.syncCountryCode()
    this.updateValidity(event)
  }

  syncCountryCode = () => {
    const selectedCode = this.iti.getSelectedCountry()?.iso2?.toUpperCase()
    if (!selectedCode) return
    this.inputTarget.dataset.countryCode = selectedCode
    const name = this.inputTarget.name.replace(/\[number\]$/, "[country_code]")
    if (name === this.inputTarget.name) return

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

  updateValidity = (event) => {
    if (!this.ready) return

    if (event?.type === "input" || event?.type === "countrychange") this.serverInvalid = false
    const hasValue = this.inputTarget.value.trim().length > 0
    const valid = this.iti.isValidNumber()
    const invalid = this.serverInvalid || (hasValue && !valid)
    this.inputTarget.dataset.valid = valid ? "true" : "false"
    this.inputTarget.setAttribute("aria-invalid", String(invalid))
    this.inputTarget.classList.toggle("border-rose-500", invalid)
    this.inputTarget.classList.toggle("bg-rose-50", invalid)
    this.inputTarget.dispatchEvent(new CustomEvent("international-phone:validated", { bubbles: true }))
  }
}
