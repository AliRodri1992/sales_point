import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A one-render handoff for explicit language changes. Contact data never goes to browser storage.
let pendingDraft = null

function actionColor(hex) {
  const rgb = hex.match(/[a-f\d]{2}/gi).map(value => parseInt(value, 16))
  let factor = 1
  let channels = rgb
  const contrast = values => {
    const linear = values.map(value => {
      const channel = value / 255
      return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
    })
    return 1.05 / (linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722 + 0.05)
  }
  while (contrast(channels) < 4.8) {
    factor *= 0.95
    channels = rgb.map(value => Math.round(value * factor))
  }
  return `#${channels.map(value => value.toString(16).padStart(2, "0")).join("")}`
}

export default class extends Controller {
  static targets = ["step", "node", "progress", "form", "themeDropdown", "themeButton", "themeOption", "success", "feedback"]
  static values = { networkMessage: String, serverMessage: String, closeLabel: String }

  connect() {
    this.errorsShown = new Set()
    this.currentStep = this.initialStep()
    this.theme = "emerald"
    if (this.hasFormTarget) {
      this.fields.forEach(field => {
        if (this.errorTarget(field)?.textContent.trim()) this.errorsShown.add(field.dataset.demoField)
      })
      const draft = pendingDraft
      pendingDraft = null
      if (draft?.url === window.location.href) this.restoreDraft(draft)
    }
    this.applyTheme(this.theme)
    this.renderStep()
    if (this.hasSuccessTarget) requestAnimationFrame(() => this.successTarget.focus())
    else if (this.errorsShown.size) requestAnimationFrame(() => this.focusFirstInvalid())
  }

  get fields() {
    return Array.from(this.formTarget.querySelectorAll("[data-demo-field]"))
  }

  initialStep() {
    return this.stepTargets.find(step => step.querySelector('[aria-invalid="true"]'))?.dataset.step === "2" ? 2 : 1
  }

  next(event) {
    event.preventDefault()
    if (this.validateStep(1)) this.currentStep = 2
    else this.showValidationAlert()
    this.renderStep()
    this.focusFirstInvalid()
  }

  back(event) {
    event.preventDefault()
    this.currentStep = 1
    this.renderStep()
    this.focusFirstInvalid()
  }

  submit(event) {
    if (this.currentStep === 1) return this.next(event)
    const firstValid = this.validateStep(1)
    const secondValid = this.validateStep(2)
    if (firstValid && secondValid) return
    event.preventDefault()
    this.currentStep = firstValid ? 2 : 1
    this.renderStep()
    this.showValidationAlert()
    this.focusFirstInvalid()
  }

  validateStep(number) {
    const fields = this.fields.filter(field => field.closest('[data-demo-request-wizard-target="step"]').dataset.step === String(number))
    return fields.map(field => this.validateField(field)).every(Boolean)
  }

  errorTarget(field) {
    return this.formTarget.querySelector(`#demo_request_${field.dataset.demoField}_error`)
  }

  messageFor(field) {
    const value = field.value.trim()
    const data = field.dataset
    if (field.type === "checkbox") return field.checked ? "" : data.demoAccepted
    if (field.required && !value) return data.demoRequired
    const length = Array.from(value).length
    if (field.minLength > 0 && length < field.minLength) return data.demoTooShort
    if (field.maxLength >= 0 && length > field.maxLength) return data.demoTooLong
    if (field.type === "email" && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return data.demoInvalid
    if (data.demoField === "phone" && data.valid !== "true") {
      if (data.phoneStatus === "loading") return data.demoPending
      if (data.phoneStatus === "failed") return data.demoUnavailable
      return data.demoInvalid
    }
    if (data.demoField === "branches") {
      const number = Number(value)
      if (!Number.isInteger(number)) return data.demoInteger
      if (number < Number(field.min)) return data.demoMinimum
      if (number > Number(field.max)) return data.demoMaximum
    }
    return ""
  }

  validateField(field) {
    this.errorsShown.add(field.dataset.demoField)
    const message = this.messageFor(field) || ""
    const error = this.errorTarget(field)
    error.textContent = message
    error.classList.toggle("hidden", !message)
    field.setAttribute("aria-invalid", String(!!message))
    field.classList.toggle("demo-request__input--invalid", !!message)
    return !message
  }

  revalidate(event) {
    const field = event.target.closest("[data-demo-field]")
    if (field && this.errorsShown.has(field.dataset.demoField)) this.validateField(field)
  }

  validateOnBlur(event) {
    const field = event.target.closest("[data-demo-field]")
    if (field && (field.value.trim() || this.errorsShown.has(field.dataset.demoField))) this.validateField(field)
  }

  focusFirstInvalid() {
    const step = this.stepTargets.find(item => Number(item.dataset.step) === this.currentStep)
    if (!step) return
    const invalid = Array.from(step.querySelectorAll("[data-demo-field]")).find(field => this.errorTarget(field)?.textContent.trim())
    const target = invalid?.tagName === "SELECT"
      ? invalid.closest(".delta-select-container")?.querySelector('button[aria-haspopup="listbox"]') || invalid
      : invalid || step.querySelector(".demo-step-title")
    target?.focus()
  }

  renderStep() {
    if (!this.hasFormTarget) return
    this.stepTargets.forEach(step => step.classList.toggle("hidden", Number(step.dataset.step) !== this.currentStep))
    this.progressTarget.style.width = this.currentStep === 1 ? "0%" : "100%"
    this.nodeTargets.forEach(node => {
      const step = Number(node.dataset.step)
      node.dataset.active = String(step <= this.currentStep)
      if (step === this.currentStep) node.setAttribute("aria-current", "step")
      else node.removeAttribute("aria-current")
    })
  }

  showValidationAlert() {
    window.Swal?.fire({ toast: true, icon: "warning", position: "top-end", timer: 3200,
      timerProgressBar: true, showConfirmButton: false, title: this.formTarget.dataset.validationTitle })
  }

  submitStart() {
    this.failedNotified = false
    this.feedbackTarget.classList.add("hidden")
  }

  beforeResponse(event) {
    const status = event.detail.fetchResponse.statusCode
    if (status < 400 || status === 422) return
    event.preventDefault()
    this.showSubmissionError(this.serverMessageValue)
  }

  requestError(event) {
    event.preventDefault()
    this.showSubmissionError(this.networkMessageValue)
  }

  submitEnd(event) {
    if (event.detail.error && !this.failedNotified) this.showSubmissionError(this.networkMessageValue)
  }

  showSubmissionError(message) {
    if (this.failedNotified) return
    this.failedNotified = true
    const button = this.formTarget.querySelector('input[type="submit"]')
    if (window.Swal) {
      window.Swal.fire({ toast: true, icon: "error", position: "top-end", title: message,
        showConfirmButton: false, showCloseButton: true, closeButtonAriaLabel: this.closeLabelValue,
        didClose: () => { if (button?.isConnected) button.focus() } })
      requestAnimationFrame(() => button?.focus())
    } else {
      this.feedbackTarget.textContent = message
      this.feedbackTarget.classList.remove("hidden")
      this.feedbackTarget.focus()
    }
  }

  changeLanguage(event) {
    if (!this.hasFormTarget) return
    event.preventDefault()
    pendingDraft = { url: window.location.href, step: this.currentStep, theme: this.theme,
      fields: this.fields.map(field => ({ name: field.dataset.demoField, value: field.value,
        checked: field.checked, country: field.dataset.countryCode })), touched: [...this.errorsShown] }
    Turbo.visit(window.location.href, { action: "replace" })
    document.addEventListener("turbo:load", () => setTimeout(() => { pendingDraft = null }, 0), { once: true })
  }

  restoreDraft(draft) {
    draft.fields.forEach(saved => {
      const field = this.fields.find(item => item.dataset.demoField === saved.name)
      if (!field) return
      field.value = saved.value
      if (field.tagName === "SELECT") field.dispatchEvent(new Event("change", { bubbles: true }))
      if (field.type === "checkbox") field.checked = saved.checked
      if (saved.country) field.dataset.countryCode = saved.country
    })
    this.currentStep = draft.step
    this.theme = draft.theme
    this.fields.filter(field => draft.touched.includes(field.dataset.demoField)).forEach(field => this.validateField(field))
  }

  toggleTheme() {
    if (!this.themeDropdownTarget.classList.contains("hidden")) return this.closeTheme()
    this.themeDropdownTarget.classList.remove("hidden")
    this.themeButtonTarget.setAttribute("aria-expanded", "true")
    this.themeOptionTargets.find(option => option.getAttribute("aria-pressed") === "true")?.focus()
  }

  closeTheme() {
    this.themeDropdownTarget.classList.add("hidden")
    this.themeButtonTarget.setAttribute("aria-expanded", "false")
  }

  selectTheme(event) {
    this.applyTheme(event.currentTarget.dataset.theme)
    this.closeTheme()
    this.themeButtonTarget.focus()
  }

  applyTheme(theme) {
    const option = this.themeOptionTargets.find(item => item.dataset.theme === theme) || this.themeOptionTargets[0]
    this.theme = option.dataset.theme
    this.element.style.setProperty("--demo-primary-start", actionColor(option.dataset.start))
    this.element.style.setProperty("--demo-primary-end", actionColor(option.dataset.end))
    this.themeOptionTargets.forEach(item => item.setAttribute("aria-pressed", String(item === option)))
  }

  themeKeydown(event) {
    if (this.themeDropdownTarget.classList.contains("hidden")) return
    if (event.key === "Escape") {
      event.preventDefault()
      this.closeTheme()
      this.themeButtonTarget.focus()
    } else if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) {
      event.preventDefault()
      const index = this.themeOptionTargets.indexOf(document.activeElement)
      const direction = ["ArrowLeft", "ArrowUp"].includes(event.key) ? -1 : 1
      this.themeOptionTargets[(index + direction + this.themeOptionTargets.length) % this.themeOptionTargets.length].focus()
    }
  }

  closeThemeOutside(event) {
    if (!this.themeDropdownTarget.contains(event.target) && !this.themeButtonTarget.contains(event.target)) this.closeTheme()
  }
}
