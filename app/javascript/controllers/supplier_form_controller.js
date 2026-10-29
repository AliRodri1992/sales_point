import { Controller } from "@hotwired/stimulus"

// Accessible supplier dossier navigation; one Rails form, one submission.
export default class extends Controller {
  static targets = ["step", "tab", "circle", "previous", "next", "submit", "summary",
    "addressValidationError", "progress", "progressBar", "activeLabel", "position", "navigation"]
  static values = {
    index: { type: Number, default: 0 },
    addressValidationUrl: String,
    newRecord: Boolean
  }

  connect() {
    this.validating = false
    this.allowSubmit = false
    this.onFieldChange = (event) => {
      if (event.target.closest("[data-supplier-address-validation]")) {
        this.clearAddressFieldError(event.target)
      } else if (event.target.matches("input[required], select[required], textarea[required]")) {
        this.validateField(event.target)
      }
      this.refreshStepIndicators()
    }
    for (const eventName of ["input", "change"]) {
      this.element.addEventListener(eventName, this.onFieldChange)
    }
    this.onOutsideNavigationClick = (event) => {
      if (this.hasNavigationTarget && !this.navigationTarget.contains(event.target)) {
        this.navigationTarget.open = false
      }
    }
    document.addEventListener("click", this.onOutsideNavigationClick)
    const invalid = this.stepTargets.findIndex((step) => step.querySelector("[aria-invalid='true'], .field_with_errors, [data-server-field-error]"))
    if (invalid >= 0) this.indexValue = invalid
    this.render()
  }

  disconnect() {
    for (const eventName of ["input", "change"]) {
      this.element.removeEventListener(eventName, this.onFieldChange)
    }
    document.removeEventListener("click", this.onOutsideNavigationClick)
  }

  fieldWrapper(field) {
    return field.closest("[data-controller='international-phone']")?.parentElement || field.closest(".grid > div") || field.parentElement
  }

  clearFieldError(field) {
    field.removeAttribute("aria-invalid")
    field.classList.remove("border-rose-500", "bg-rose-50")
    this.fieldWrapper(field)?.querySelector("[data-required-error]")?.remove()
  }

  showFieldError(field, reason) {
    const wrapper = this.fieldWrapper(field)
    if (!wrapper) return
    field.setAttribute("aria-invalid", "true")
    field.classList.add("border-rose-500", "bg-rose-50")
    let message = wrapper.querySelector("[data-required-error]")
    if (!message) {
      message = document.createElement("p")
      message.dataset.requiredError = "true"
      message.className = "mt-1 text-xs text-rose-600"
      wrapper.append(message)
    }
    const label = field.labels?.[0]?.textContent?.replace(/\*/g, "").trim() || field.name
    const template = reason === "format" ? this.element.dataset.invalidFormatMessage : this.element.dataset.requiredMessage
    message.textContent = template.replace("%{field}", label)
  }

  validateField(field) {
    const value = field.value.trim()
    const valid = value.length > 0 && field.validity.valid
    if (valid) this.clearFieldError(field)
    else this.showFieldError(field, value.length === 0 ? "required" : "format")
    return valid
  }

  addressRoot() {
    return this.stepTargets[1]?.querySelector("[data-supplier-address-validation]:not([hidden])")
  }

  addressInput(root, name) {
    return root.querySelector('[name$="[' + name + ']"]')
  }

  clearAddressFieldError(field) {
    const root = field.closest("[data-supplier-address-validation]")
    if (!root) return
    if (field.name?.endsWith("[country_id]")) {
      this.clearAddressErrors(root)
      return
    }
    const name = field.name?.split("[").pop()?.replace("]", "")
    const message = root.querySelector('[data-supplier-address-model-error="' + name + '"]')
    if (!message) return
    message.classList.add("hidden")
    message.textContent = ""
    field.removeAttribute("aria-invalid")
    field.classList.remove("border-rose-500", "bg-rose-50")
  }

  clearAddressErrors(root) {
    root.querySelectorAll("[data-supplier-address-model-error]").forEach((message) => {
      message.classList.add("hidden")
      message.textContent = ""
    })
    root.querySelectorAll('[aria-invalid="true"]').forEach((field) => {
      field.removeAttribute("aria-invalid")
      field.classList.remove("border-rose-500", "bg-rose-50")
    })
    if (this.hasAddressValidationErrorTarget) {
      this.addressValidationErrorTarget.textContent = ""
      this.addressValidationErrorTarget.classList.add("hidden")
    }
  }

  showAddressErrors(root, errors) {
    let firstField = null
    for (const [name, messages] of Object.entries(errors)) {
      const message = root.querySelector('[data-supplier-address-model-error="' + name + '"]')
      if (!message) continue
      message.textContent = (Array.isArray(messages) ? messages : [messages]).join(" ")
      message.classList.remove("hidden")
      const field = this.addressInput(root, name)
      if (!field) continue
      field.setAttribute("aria-invalid", "true")
      field.classList.add("border-rose-500", "bg-rose-50")
      firstField ||= field
    }
    return firstField
  }

  async validateFiscalAddress(index) {
    if (index !== 1 || !this.addressValidationUrlValue) return true
    const root = this.addressRoot()
    if (!root) return true
    const attributes = ["street", "exterior_number", "interior_number",
      "neighborhood", "city", "state", "postal_code", "country_id"]
    const body = new URLSearchParams()
    attributes.forEach((name) => {
      body.append("address[" + name + "]", this.addressInput(root, name)?.value || "")
    })
    this.clearAddressErrors(root)

    try {
      const response = await fetch(this.addressValidationUrlValue, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        }
      })
      if (response.ok) return true
      if (response.status !== 422) throw new Error("Address validation unavailable")

      const result = await response.json()
      const first = this.showAddressErrors(root, result.errors || {})
      this.invalidAddressField = first
      return false
    } catch (_error) {
      if (this.hasAddressValidationErrorTarget) {
        this.addressValidationErrorTarget.textContent =
          this.element.dataset.supplierFormValidationUnavailableMessage
        this.addressValidationErrorTarget.classList.remove("hidden")
      }
      this.invalidAddressField = null
      return false
    }
  }

  focusField(field) {
    const dropdown = field?.closest('[data-controller~="delta-select"]')
    const target = dropdown?.querySelector('button[aria-haspopup="listbox"]') || field
    target?.focus()
  }

  navigationKeydown(event) {
    if (event.key !== "Escape" || !this.hasNavigationTarget || !this.navigationTarget.open) return
    event.preventDefault()
    this.navigationTarget.open = false
    this.navigationTarget.querySelector("summary")?.focus()
  }

  async select(event) {
    if (this.validating) return
    if (this.hasNavigationTarget) this.navigationTarget.open = false
    const destination = Number(event.currentTarget.dataset.stepIndex)
    this.validating = true
    try {
      if (this.newRecordValue && destination > this.indexValue && !await this.validateThrough(destination)) return
      this.indexValue = destination
    } finally {
      this.validating = false
    }
  }

  async next() {
    if (this.validating) return
    this.validating = true
    try {
      if (this.newRecordValue && !await this.validateStep(this.indexValue)) return
      this.indexValue = Math.min(this.indexValue + 1, this.stepTargets.length - 1)
    } finally {
      this.validating = false
    }
  }

  async submit(event) {
    if (this.allowSubmit) {
      this.allowSubmit = false
      return
    }
    event.preventDefault()
    if (this.validating) return
    this.validating = true
    try {
      if (!await this.validateThrough(this.stepTargets.length - 1)) return
      if (this.newRecordValue && this.indexValue !== this.stepTargets.length - 1) {
        this.indexValue = this.stepTargets.length - 1
        return
      }
      this.allowSubmit = true
      this.element.requestSubmit(this.submitTarget)
    } finally {
      this.validating = false
    }
  }

  previous() {
    if (this.validating) return
    this.indexValue = Math.max(this.indexValue - 1, 0)
  }

  indexValueChanged() {
    if (this.hasStepTarget) this.render()
  }

  async validateThrough(destination) {
    for (let index = 0; index < destination; index += 1) {
      if (!await this.validateStep(index)) return false
    }
    return true
  }

  async validateStep(index) {
    const step = this.stepTargets[index]
    const fields = [...step.querySelectorAll("input[required], select[required], textarea[required]")]
      .filter((field) => !field.disabled && !field.closest("[data-supplier-address-validation]") &&
        !field.closest("template"))
    const invalid = fields.filter((field) => !this.validateField(field))
    const addressValid = await this.validateFiscalAddress(index)
    if (!invalid.length && addressValid) return true

    this.indexValue = index
    this.render()
    this.focusField(invalid[0] || this.invalidAddressField)
    return false
  }

  summaryLabel(field) {
    const explicit = field.labels?.[0]?.textContent?.replace(/\\*/g, "").trim()
    if (explicit) return explicit
    const id = field.id
    const matching = id ? this.element.querySelector(`label[for="${CSS.escape(id)}"]`) : null
    if (matching) return matching.textContent.replace(/\\*/g, "").trim()
    return field.name.split("[").pop().replace("]", "").replace(/_/g, " ")
  }

  summaryValue(field) {
    if (field.type === "file") return [...field.files].map((file) => file.name).join(", ")
    if (field.type === "checkbox") return field.checked ? "✓" : "—"
    if (field.type === "radio") return field.checked ? field.value : null
    if (field.tagName === "SELECT") {
      return [...field.selectedOptions].map((option) => option.textContent.trim()).filter(Boolean).join(", ")
    }
    return field.value.trim()
  }

  appendSummaryGroup(title, fields) {
    const entries = fields.filter((field) =>
      field.name && !field.disabled && !["hidden", "submit", "button"].includes(field.type) &&
      !field.name.endsWith("[_destroy]") && !field.closest("template") &&
      !field.closest("[data-supplier-nested-item]")?.querySelector("[data-supplier-nested-destroy]:checked")
    ).map((field) => ({
      label: this.summaryLabel(field),
      value: this.summaryValue(field),
      type: field.type
    })).filter(({ value }) => value !== null && value !== "")

    if (!entries.length) entries.push({ label: '—', value: '—' })

    const group = document.createElement("section")
    group.className = "rounded-xl border border-slate-200 bg-slate-50/50 p-4"
    const heading = document.createElement("h3")
    heading.className = "mb-3 text-sm font-bold text-slate-900"
    heading.textContent = title
    group.append(heading)

    const list = document.createElement("dl")
    list.className = "grid gap-3 sm:grid-cols-2"
    entries.forEach(({ label, value }) => {
      const item = document.createElement("div")
      const term = document.createElement("dt")
      term.className = "text-xs font-semibold text-slate-500"
      term.textContent = label
      const description = document.createElement("dd")
      description.className = "mt-1 break-words whitespace-pre-wrap text-sm text-slate-900"
      description.textContent = value
      item.append(term, description)
      list.append(item)
    })
    group.append(list)
    this.summaryTarget.append(group)
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return
    this.summaryTarget.replaceChildren()

    // Review every editable step, not just General and Fiscal.
    this.stepTargets.slice(0, -1).forEach((step) => {
      const title = step.querySelector("h2")?.textContent?.trim() || ""
      const fields = [...step.querySelectorAll("input, select, textarea")]
        .filter((field) => !field.closest("[data-supplier-nested-item]"))
      const nestedItems = [...step.querySelectorAll("[data-supplier-nested-item]")]
        .filter((item) => item.querySelector("[data-supplier-nested-destroy]")?.value !== "1")

      // Fiscal information and its single fiscal address belong in one summary card.
      if (step === this.stepTargets[1] && nestedItems.length === 1) {
        this.appendSummaryGroup(title, [
          ...fields,
          ...nestedItems[0].querySelectorAll("input, select, textarea")
        ])
        return
      }

      this.appendSummaryGroup(title, fields)
      nestedItems.forEach((item, index) => {
        this.appendSummaryGroup(`${title} · ${index + 1}`, [...item.querySelectorAll("input, select, textarea")])
      })
    })
  }

  refreshStepIndicators() {
    this.tabTargets.forEach((tab, index) => {
      if (index === this.stepTargets.length - 1) return
      const invalid = this.stepTargets[index]?.querySelector('[aria-invalid="true"], .field_with_errors, [data-server-field-error]')
      const required = [...(this.stepTargets[index]?.querySelectorAll('input[required], select[required], textarea[required]') || [])]
        .filter((field) => !field.disabled && !field.closest("template"))
      const editable = [...(this.stepTargets[index]?.querySelectorAll("input:not([type='hidden']), select, textarea") || [])]
        .filter((field) => !field.disabled && !field.closest("template"))
      const hasContent = editable.some((field) => field.type === "checkbox" ? field.checked : field.value.trim() !== "")
      const complete = !invalid && (required.length > 0 ? required.every((field) => field.value.trim() !== "" && field.checkValidity()) : true)
      const state = invalid ? "error" : complete ? "complete" : hasContent ? "progress" : "pending"
      tab.dataset.stepState = state
      tab.classList.toggle("ring-1", !!invalid)
      tab.classList.toggle("ring-rose-400", !!invalid)
      let indicator = tab.querySelector("[data-step-indicator]")
      if (!indicator) {
        indicator = document.createElement("span")
        indicator.dataset.stepIndicator = "true"
        indicator.className = "inline-flex size-5 shrink-0 items-center justify-center rounded-full text-xs font-bold"
        tab.append(indicator)
      }
      indicator.textContent = { complete: "✓", error: "!", progress: "·", pending: "○" }[state]
      indicator.setAttribute("role", "img")
      indicator.setAttribute("aria-label", state === "progress" ? this.element.dataset.supplierFormInProgressLabel : (this.element.dataset[`supplierForm${state[0].toUpperCase() + state.slice(1)}Label`] || state))
      indicator.classList.toggle("bg-emerald-100", state === "complete")
      indicator.classList.toggle("text-emerald-800", state === "complete")
      indicator.classList.toggle("bg-rose-100", state === "error")
      indicator.classList.toggle("text-rose-800", state === "error")
      indicator.classList.toggle("bg-amber-100", state === "progress")
      indicator.classList.toggle("text-amber-800", state === "progress")
      indicator.classList.toggle("bg-slate-100", state === "pending")
      indicator.classList.toggle("text-slate-600", state === "pending")
    })
    if (this.hasProgressTarget) {
      const count = this.tabTargets.slice(0, -1).filter((tab) => tab.dataset.stepState === "complete").length
      const template = this.element.dataset.supplierFormProgressLabel || "%{count} / %{total}"
      this.progressTarget.textContent = template.replace("%{count}", String(count))
        .replace("%{total}", String(this.stepTargets.length - 1))
    }
  }

  render() {
    const current = this.tabTargets[this.indexValue]
    if (this.hasActiveLabelTarget && current) {
      this.activeLabelTarget.textContent = current.querySelector("[data-supplier-form-step-label]")?.textContent?.trim() || ""
    }
    if (this.hasPositionTarget) {
      const template = this.element.dataset.supplierFormStepCounterTemplate || "%{current} / %{total}"
      this.positionTarget.textContent = template.replace("%{current}", String(this.indexValue + 1))
        .replace("%{total}", String(this.stepTargets.length))
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${((this.indexValue + 1) / this.stepTargets.length) * 100}%`
    }
    this.stepTargets.forEach((step, index) => {
      step.hidden = index !== this.indexValue
      step.classList.toggle("hidden", index !== this.indexValue)
    })
    this.tabTargets.forEach((tab, index) => {
      const active = index === this.indexValue
      if (active) tab.setAttribute("aria-current", this.newRecordValue ? "step" : "location")
      else tab.removeAttribute("aria-current")
      tab.classList.toggle("bg-emerald-50", active)
      tab.classList.toggle("text-emerald-800", active)
      tab.classList.toggle("border-emerald-500", active)
      tab.classList.toggle("ring-2", active)
      tab.classList.toggle("ring-emerald-100", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("bg-white", !active)
    })
    this.circleTargets.forEach((circle, index) => {
      const active = index === this.indexValue
      circle.classList.toggle("bg-emerald-600", active)
      circle.classList.toggle("border-emerald-600", active)
      circle.classList.toggle("text-white", active)
      circle.classList.toggle("bg-white", !active)
      circle.classList.toggle("border-slate-200", !active)
      circle.classList.toggle("text-slate-500", !active)
    })
    this.refreshStepIndicators()
    if (this.indexValue === this.stepTargets.length - 1) this.updateSummary()
    if (this.hasSubmitTarget) this.submitTarget.hidden = this.newRecordValue && this.indexValue !== this.stepTargets.length - 1
    if (this.hasPreviousTarget) this.previousTarget.hidden = !this.newRecordValue || this.indexValue === 0
    if (this.hasNextTarget) this.nextTarget.hidden = !this.newRecordValue || this.indexValue === this.stepTargets.length - 1
  }
}
