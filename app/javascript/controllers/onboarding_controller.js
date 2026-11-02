import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form", "feedback", "address"]
  static values = { error: String, copy: Object }

  connect() {
    this.touched = new Set()
    this.phoneInitialized = new Set()
    this.editedFields = new Set()
    this.snapshots = new Map()
    this.rejected = !!this.errorValue
    this.applyCountryRules()
    this.formTargets.forEach(form => this.snapshots.set(form, this.serialize(form)))
    this.fields.forEach(field => {
      if (field.getAttribute("aria-invalid") === "true") this.touched.add(field)
    })
    if (this.errorValue) requestAnimationFrame(() => {
      this.focusError()
      this.showError(this.errorValue)
    })
  }

  get fields() {
    return Array.from(this.element.querySelectorAll("[data-onboarding-field]"))
  }

  serialize(form) {
    return JSON.stringify(Array.from(form.querySelectorAll("[data-onboarding-field],input[type=checkbox]"))
      .map(field => [field.name, field.type === "checkbox" ? field.checked : field.value]))
  }

  get dirty() {
    return this.rejected || this.formTargets.some(form => this.snapshots.get(form) !== this.serialize(form))
  }

  changed(event) {
    if (event.target.matches('select[name$="[country_id]"]')) this.applyCountryRules()
    const field = event.target.closest("[data-onboarding-field]")
    if (field) this.editedFields.add(field)
    if (field && this.touched.has(field)) this.validate(field)
  }

  blur(event) {
    const field = event.target.closest("[data-onboarding-field]")
    if (field && (field.value.trim() || this.touched.has(field))) this.validate(field)
  }

  phoneReady(event) {
    const field = event.target.closest("[data-onboarding-field]")
    if (!field) return
    if (!this.phoneInitialized.has(field)) {
      this.phoneInitialized.add(field)
      // Initial international formatting is not an edit made by the user.
      if (this.snapshots.has(field.form) && !this.editedFields.has(field)) {
        const saved = JSON.parse(this.snapshots.get(field.form))
        const entry = saved.find(item => item[0] === field.name)
        if (entry) entry[1] = field.value
        this.snapshots.set(field.form, JSON.stringify(saved))
      }
    }
    if (this.touched.has(field)) this.validate(field)
  }

  applyCountryRules() {
    if (!this.hasAddressTarget) return
    const country = this.addressTarget.querySelector('select[name$="[country_id]"]')
    const option = country.selectedOptions[0]
    const required = new Set(["street", "city", "country_id", ...(option?.dataset.requiredFields || "").split(",")])
    this.addressTarget.querySelectorAll("[data-field-key]").forEach(wrapper => {
      const field = wrapper.querySelector("input,select")
      field.required = required.has(wrapper.dataset.fieldKey)
      wrapper.querySelector("[data-onboarding-required]").textContent = field.required ? "*" : ""
      if (wrapper.dataset.fieldKey === "postal_code") field.dataset.onboardingPattern = option?.dataset.postalPattern || ""
      if (this.touched?.has(field)) this.validate(field)
    })
  }

  errorElement(field) {
    return document.getElementById(field.getAttribute("aria-describedby"))
  }

  message(field) {
    const value = field.value.trim()
    const data = field.dataset
    if (!value) return field.required ? data.blank : ""
    const length = Array.from(value).length
    if (field.minLength > 0 && length < field.minLength) return data.tooShort
    if (field.maxLength >= 0 && length > field.maxLength) return data.tooLong
    if (data.onboardingPattern && !new RegExp(data.onboardingPattern, "i").test(value)) return data.invalid
    if (field.type === "tel" && data.valid !== "true") return `${data.label} ${this.copyValue.phone_invalid}`
    return ""
  }

  validate(field) {
    this.touched.add(field)
    const message = this.message(field) || ""
    const error = this.errorElement(field)
    error.textContent = message
    error.classList.toggle("hidden", !message)
    field.setAttribute("aria-invalid", String(!!message))
    return !message
  }

  submit(event) {
    if (!this.formTargets.includes(event.target)) return
    if (this.submitting) return event.preventDefault()
    const fields = this.fields.filter(field => field.form === event.target)
    const valid = fields.map(field => this.validate(field)).every(Boolean)
    if (!valid) {
      event.preventDefault()
      this.focusError(event.target)
    }
  }

  focusError(form) {
    const scope = form || this.element
    const field = scope.querySelector('[data-onboarding-field][aria-invalid="true"]')
    const target = field?.tagName === "SELECT"
      ? field.closest('[data-controller~="delta-select"]')?.querySelector('button[aria-haspopup="listbox"]') || field
      : field || scope.querySelector(".onboarding-field-error:not(.hidden)") || this.feedbackTarget
    if (!target.matches("input,select,button,textarea")) target.setAttribute("tabindex", "-1")
    target.focus()
  }

  async beforeVisit(event) {
    const url = new URL(event.detail.url, location.href)
    if (url.hash && url.pathname === location.pathname && url.search === location.search) return
    if (this.allowNavigation || this.submitting || !this.dirty) return
    event.preventDefault()
    if (this.confirming) return
    this.confirming = true
    const previous = document.activeElement
    const c = this.copyValue
    const discard = window.Swal ? (await window.Swal.fire({ icon: "question", title: c.unsaved_title,
      text: c.unsaved_body, showCancelButton: true, confirmButtonText: c.discard, cancelButtonText: c.keep_editing,
      focusCancel: true })).isConfirmed : window.confirm(c.unsaved_body)
    this.confirming = false
    if (discard) {
      this.allowNavigation = true
      Turbo.visit(url.href)
    } else if (previous?.isConnected) previous.focus()
  }

  beforeUnload(event) {
    if (!this.submitting && !this.allowNavigation && this.dirty) {
      event.preventDefault()
      event.returnValue = ""
    }
  }

  submitStart(event) {
    this.submitting = true
    this.notified = false
    this.submitter = event.detail.formSubmission.submitter
    this.feedbackTarget.classList.add("hidden")
  }

  submitEnd(event) {
    this.submitting = false
    if (event.detail.success) {
      this.rejected = false
      this.allowNavigation = true
    }
    if (event.detail.error && !this.notified) this.showError(this.copyValue.network_error)
  }

  beforeResponse(event) {
    const status = event.detail.fetchResponse.statusCode
    if (status < 400 || status === 422) return
    event.preventDefault()
    this.showError(status === 401 || status === 403 ? this.copyValue.access_error : this.copyValue.server_error)
  }

  requestError(event) {
    event.preventDefault()
    this.showError(this.copyValue.network_error)
  }

  showError(message) {
    if (this.notified) return
    this.notified = true
    this.feedbackTarget.textContent = message
    this.feedbackTarget.classList.remove("hidden")
    window.Swal?.fire({ toast: true, icon: "error", position: "top-end", title: message,
      showConfirmButton: false, showCloseButton: true, closeButtonAriaLabel: this.copyValue.close,
      didClose: () => { if (this.submitter?.isConnected) this.submitter.focus() } })
  }
}
