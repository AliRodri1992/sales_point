import { Controller } from "@hotwired/stimulus"

const RFC_FORMAT = /^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$/i
const EMAIL_FORMAT = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export default class extends Controller {
  static targets = [
    "wrapper", "step", "node", "progress", "stepCounter", "setupType", "setupCard",
    "input", "dropdown", "dropdownMenu", "dropdownLabel", "businessSector",
    "migrationVolume", "migrationPriority", "branchesHidden", "currency",
    "terminals", "payments", "migrationFields", "terms", "back", "next",
    "companyName", "taxId", "firstName", "lastName", "password", "confirmation",
    "timezone", "summary"
  ]

  connect() {
    this.currentStep = Number(this.wrapperTarget.dataset.initialStep || 1)
    if (this.currentStep < 1 || this.currentStep > 5) this.currentStep = 1
    this.selectedSetupType = this.setupTypeTarget.value || ""
    this.submitting = false
    this.closeHandler = this.closeDropdowns.bind(this)
    document.addEventListener("click", this.closeHandler)
    this.updateSetupCards()
    this.updateDropdownSelections()
    this.updateStep()
  }

  disconnect() {
    document.removeEventListener("click", this.closeHandler)
  }

  next() {
    if (this.submitting || !this.validateStep()) return
    if (this.currentStep === 5) {
      this.element.querySelector("form")?.requestSubmit()
    } else {
      this.currentStep += 1
      this.updateStep()
    }
  }

  previous() {
    if (this.submitting || this.currentStep <= 1) return
    this.currentStep -= 1
    this.updateStep()
  }

  selectSetup(event) {
    event.preventDefault()
    this.selectedSetupType = event.currentTarget.dataset.setupType
    this.setupTypeTarget.value = this.selectedSetupType
    this.updateSetupCards()
    this.clearFieldError({ target: event.currentTarget })
  }

  toggleDropdown(event) {
    event.preventDefault()
    event.stopPropagation()
    const trigger = event.currentTarget
    const menu = this.dropdownMenuTargets.find((element) => element.dataset.dropdownName === trigger.dataset.dropdownName)
    if (!menu) return
    const opening = menu.classList.contains("hidden")
    this.closeDropdowns()
    if (opening) {
      menu.hidden = false
      menu.classList.remove("hidden")
      trigger.setAttribute("aria-expanded", "true")
    }
  }

  selectDropdown(event) {
    event.preventDefault()
    const option = event.currentTarget
    const name = option.dataset.dropdownName
    const input = this.dropdownInputTarget(name)
    if (!input || !option.dataset.dropdownValue) return
    this[input + "Target"].value = option.dataset.dropdownValue
    this.updateDropdownOptions(name, option.dataset.dropdownValue)
    this.closeDropdowns()
    const trigger = this.dropdownTargets.find((button) => button.dataset.dropdownName === name)
    trigger?.focus()
    if (trigger) this.clearFieldError({ target: trigger })
  }

  dropdownInputTarget(name) {
    return {
      "business-sector": "businessSector", currency: "currency", terminals: "terminals",
      "payment-integration": "payments", timezone: "timezone"
    }[name]
  }

  closeDropdowns() {
    this.dropdownMenuTargets.forEach((menu) => {
      menu.classList.add("hidden")
      menu.hidden = true
    })
    this.dropdownTargets.forEach((button) => button.setAttribute("aria-expanded", "false"))
  }

  updateDropdownSelections() {
    [
      ["business-sector", this.businessSectorTarget.value],
      ["currency", this.currencyTarget.value],
      ["terminals", this.terminalsTarget.value],
      ["payment-integration", this.paymentsTarget.value],
      ["timezone", this.timezoneTarget.value]
    ].forEach(([name, value]) => this.updateDropdownOptions(name, value))
  }

  updateDropdownOptions(name, selectedValue) {
    const menu = this.dropdownMenuTargets.find((target) => target.dataset.dropdownName === name)
    if (!menu) return
    let chosen
    menu.querySelectorAll("[data-dropdown-option]").forEach((option) => {
      const selected = option.dataset.dropdownValue === selectedValue
      if (selected) chosen = option
      option.classList.toggle("bg-emerald-700", selected)
      option.classList.toggle("text-white", selected)
      option.classList.toggle("text-slate-600", !selected)
      option.setAttribute("aria-selected", String(selected))
    })
    const label = this.dropdownLabelTargets.find(
      (element) => element.closest("[data-dropdown-name]")?.dataset.dropdownName === name
    )
    if (chosen && label) label.textContent = chosen.dataset.dropdownLabel || chosen.textContent.trim()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      const expanded = this.dropdownTargets.find((button) => button.getAttribute("aria-expanded") === "true")
      if (expanded) {
        event.preventDefault()
        this.closeDropdowns()
        expanded.focus()
      }
      return
    }
    if (!["ArrowDown", "ArrowUp"].includes(event.key)) return
    const target = event.target
    const menu = target.closest('[data-registration-wizard-target="dropdownMenu"]')
    if (menu) {
      const options = Array.from(menu.querySelectorAll("[data-dropdown-option]"))
      const current = options.indexOf(target)
      event.preventDefault()
      options[(current + (event.key === "ArrowDown" ? 1 : -1) + options.length) % options.length]?.focus()
    } else if (target.matches('[data-registration-wizard-target="dropdown"]')) {
      event.preventDefault()
      if (target.getAttribute("aria-expanded") !== "true") {
        this.toggleDropdown({ preventDefault() {}, stopPropagation() {}, currentTarget: target })
      }
      const matching = this.dropdownMenuTargets.find((item) => item.dataset.dropdownName === target.dataset.dropdownName)
      const options = matching?.querySelectorAll("[data-dropdown-option]")
      if (options?.length) (event.key === "ArrowDown" ? options[0] : options[options.length - 1]).focus()
    }
  }

  selectTimezone(event) {
    this.timezoneTarget.value = event.currentTarget.value
    this.clearFieldError({ target: event.currentTarget })
  }

  selectVolume(event) {
    this.migrationVolumeTarget.value = event.currentTarget.value
    this.clearFieldError({ target: event.currentTarget })
  }

  selectPriority(event) {
    this.migrationPriorityTarget.value = event.currentTarget.value
    this.clearFieldError({ target: event.currentTarget })
  }

  togglePassword(event) {
    event.preventDefault()
    const field = event.currentTarget.closest(".relative")?.querySelector("input")
    if (!field) return
    const show = field.type === "password"
    field.type = show ? "text" : "password"
    event.currentTarget.setAttribute("aria-pressed", String(show))
  }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }
    for (let step = 1; step <= 5; step += 1) {
      this.currentStep = step
      if (!this.validateStep()) {
        event.preventDefault()
        this.updateStep()
        this.firstInvalidField?.focus()
        return
      }
    }
    this.currentStep = 5
    this.submitting = true
    this.nextTarget.disabled = true
    this.nextTarget.setAttribute("aria-busy", "true")
    this.nextTarget.querySelector("span").textContent = this.nextTarget.dataset.savingLabel
  }

  validateStep() {
    this.clearErrors()
    const handlers = [
      this.validateSetupType, this.validateAdministrator, this.validateCompany,
      this.validateEnvironment, this.validateCompletion
    ]
    const valid = handlers[this.currentStep - 1].call(this)
    if (!valid) this.firstInvalidField?.focus()
    return valid
  }

  validateSetupType() {
    return this.selectedSetupType
      ? true : this.setFieldError(this.setupCardTargets[0], this.message("required"))
  }

  validateAdministrator() {
    let valid = true
    for (const field of [this.firstNameTarget, this.lastNameTarget]) {
      if (field.value.trim().length >= 2) continue
      this.setFieldError(field, this.message("fieldRequired"))
      valid = false
    }
    const email = this.element.querySelector('input[name="user[email]"]')
    if (!email?.value.trim()) {
      this.setFieldError(email, this.wrapperTarget.dataset.validationModelEmailBlank)
      valid = false
    } else if (!EMAIL_FORMAT.test(email.value.trim())) {
      this.setFieldError(email, this.message("email"))
      valid = false
    }
    if (!this.passwordTarget.value) {
      this.setFieldError(this.passwordTarget, this.wrapperTarget.dataset.validationModelPasswordBlank)
      valid = false
    } else if (this.passwordTarget.value.length < 6) {
      this.setFieldError(this.passwordTarget, this.message("passwordLength"))
      valid = false
    }
    if (!this.confirmationTarget.value || this.passwordTarget.value !== this.confirmationTarget.value) {
      this.setFieldError(this.confirmationTarget, this.wrapperTarget.dataset.validationModelConfirmation)
      valid = false
    }
    return valid
  }

  validateCompany() {
    let valid = true
    if (this.companyNameTarget.value.trim().length < 2) {
      this.setFieldError(this.companyNameTarget, this.message("fieldRequired"))
      valid = false
    }
    this.taxIdTarget.value = this.taxIdTarget.value.trim().toUpperCase()
    if (!RFC_FORMAT.test(this.taxIdTarget.value)) {
      this.setFieldError(this.taxIdTarget, this.message("taxFormat"))
      valid = false
    }
    return valid
  }

  validateEnvironment() {
    let valid = true
    for (const [name, value] of [
      ["business-sector", this.businessSectorTarget.value],
      ["currency", this.currencyTarget.value],
      ["timezone", this.timezoneTarget.value]
    ]) {
      if (value) continue
      const trigger = this.dropdownTargets.find((button) => button.dataset.dropdownName === name)
      this.setFieldError(trigger, this.message("required"))
      valid = false
    }
    if (this.selectedSetupType === "migration") {
      for (const field of [
        this.element.querySelector("#migration-volume"),
        this.element.querySelector("#migration-priority")
      ]) {
        if (field?.value) continue
        this.setFieldError(field, this.message("required"))
        valid = false
      }
    }
    return valid
  }

  validateCompletion() {
    if (this.termsTarget.checked) return true
    return this.setFieldError(this.termsTarget, this.message("terms"))
  }

  setFieldError(field, message) {
    if (!field) return false
    const wrapper = field.closest("[data-field]") || field.parentElement
    if (!wrapper) return false
    field.classList.add("border-rose-500", "bg-rose-50")
    field.setAttribute("aria-invalid", "true")
    const id = ("registration-error-" + (field.id || field.name || "selection")).replace(/[^a-z0-9-]/gi, "-")
    let error = wrapper.querySelector("[data-registration-field-error]")
    if (!error) {
      error = document.createElement("p")
      error.dataset.registrationFieldError = "true"
      error.className = "mt-1 break-words text-xs font-medium leading-4 text-rose-700"
      error.setAttribute("role", "alert")
      error.setAttribute("aria-live", "polite")
      wrapper.appendChild(error)
    }
    error.id = id
    error.textContent = message
    field.setAttribute("aria-describedby", id)
    if (!this.firstInvalidField) this.firstInvalidField = field
    return false
  }

  clearFieldError(event) {
    const wrapper = event.target.closest("[data-field]")
    if (!wrapper) return

    wrapper.querySelector("[data-registration-field-error]")?.remove()
    wrapper.querySelectorAll('[aria-invalid="true"]').forEach((field) => {
      field.removeAttribute("aria-invalid")
      field.removeAttribute("aria-describedby")
      field.classList.remove("border-rose-500", "bg-rose-50")
    })
  }

  clearErrors() {
    this.firstInvalidField = null
    this.element.querySelectorAll("[data-registration-field-error]").forEach((error) => error.remove())
    this.element.querySelectorAll('[aria-invalid="true"]').forEach((field) => {
      field.removeAttribute("aria-invalid")
      field.removeAttribute("aria-describedby")
      field.classList.remove("border-rose-500", "bg-rose-50")
    })
  }

  updateStep() {
    this.stepTargets.forEach((section) => {
      const active = Number(section.dataset.step) === this.currentStep
      section.classList.toggle("hidden", !active)
      section.setAttribute("aria-hidden", String(!active))
    })
    this.progressTarget.style.width = String(((this.currentStep - 1) / 4) * 100) + "%"
    this.nodeTargets.forEach((node) => {
      const index = Number(node.dataset.step)
      const reached = index <= this.currentStep
      node.classList.toggle("border-emerald-600", reached)
      node.classList.toggle("bg-emerald-700", reached)
      node.classList.toggle("text-white", reached)
      node.classList.toggle("border-slate-200", !reached)
      node.classList.toggle("bg-white", !reached)
      node.classList.toggle("text-slate-500", !reached)
      if (index === this.currentStep) node.setAttribute("aria-current", "step")
      else node.removeAttribute("aria-current")
    })
    this.stepCounterTarget.textContent = String(this.currentStep) + " / 5"
    this.backTarget.classList.toggle("hidden", this.currentStep === 1)
    this.nextTarget.classList.toggle("col-span-2", this.currentStep === 1)
    this.nextTarget.classList.toggle("col-start-2", this.currentStep !== 1)
    this.nextTarget.querySelector("span").textContent = this.currentStep === 5
      ? this.nextTarget.dataset.submitLabel : this.nextTarget.dataset.nextLabel
    this.migrationFieldsTarget.classList.toggle("hidden", this.selectedSetupType !== "migration")
    if (this.currentStep === 5) this.updateSummary()
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return
    const values = {
      name: [this.firstNameTarget.value, this.lastNameTarget.value].filter(Boolean).join(" "),
      email: this.element.querySelector('input[name="user[email]"]')?.value || "",
      company: this.companyNameTarget.value,
      tax: this.taxIdTarget.value,
      sector: this.dropdownValueLabel("business-sector"),
      currency: this.currencyTarget.value,
      terminals: this.dropdownValueLabel("terminals"),
      payment: this.dropdownValueLabel("payment-integration")
    }
    this.summaryTarget.querySelectorAll("[data-summary-key]").forEach((element) => {
      element.textContent = values[element.dataset.summaryKey] || "—"
    })
  }

  dropdownValueLabel(name) {
    const trigger = this.dropdownTargets.find((element) => element.dataset.dropdownName === name)
    return trigger?.querySelector('[data-registration-wizard-target="dropdownLabel"]')?.textContent.trim() || ""
  }

  updateSetupCards() {
    this.setupCardTargets.forEach((card) => {
      const selected = card.dataset.setupType === this.selectedSetupType
      card.classList.toggle("border-emerald-600", selected)
      card.classList.toggle("border-slate-200", !selected)
      card.classList.toggle("bg-emerald-50", selected)
      card.classList.toggle("bg-white", !selected)
      card.classList.toggle("ring-2", selected)
      card.classList.toggle("ring-emerald-500/30", selected)
      card.classList.toggle("shadow-md", selected)
      card.classList.toggle("shadow-sm", !selected)

      const icon = card.querySelector("[data-setup-icon]")
      icon?.classList.toggle("bg-emerald-100", selected)
      icon?.classList.toggle("text-emerald-700", selected)
      icon?.classList.toggle("bg-slate-100", !selected)
      icon?.classList.toggle("text-slate-600", !selected)

      card.querySelector("[data-setup-check]")?.classList.toggle("opacity-0", !selected)
      card.querySelector("[data-setup-selected-label]")?.classList.toggle("invisible", !selected)
      card.setAttribute("aria-pressed", String(selected))
    })
    this.migrationFieldsTarget.classList.toggle("hidden", this.selectedSetupType !== "migration")
  }

  message(key) {
    const code = "validation" + key.charAt(0).toUpperCase() + key.slice(1)
    return this.wrapperTarget.dataset[code] || this.wrapperTarget.dataset.validationRequired
  }
}
