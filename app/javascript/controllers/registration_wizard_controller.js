import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "wrapper", "step", "node", "progress", "stepCounter", "setupType",
    "setupCard", "input", "dropdown", "dropdownMenu", "dropdownLabel",
    "businessSector", "migrationVolume", "migrationPriority",
    "branchesHidden", "currency", "terminals", "payments", "migrationFields",
    "terms", "back", "next", "error", "companyName", "taxId", "firstName", "lastName",
    "password", "confirmation"
  ]

  connect() {
    this.currentStep = 1
    this.selectedSetupType = this.setupTypeTarget.value || ""
    this.updateSetupCards()
    this.updateDropdownSelections()
    this.updateStep()
    this.closeHandler = this.closeDropdowns.bind(this)
    document.addEventListener("click", this.closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.closeHandler)
  }

  next() {
    if (!this.validateStep()) return

    if (this.currentStep < 5) {
      this.currentStep += 1
      this.updateStep()
      return
    }

    this.element.querySelector("form")?.requestSubmit()
  }

  previous() {
    if (this.currentStep > 1) {
      this.currentStep -= 1
      this.updateStep()
    }
  }

  selectSetup(event) {
    event.preventDefault()
    this.selectedSetupType = event.currentTarget.dataset.setupType
    this.setupTypeTarget.value = this.selectedSetupType
    this.updateSetupCards()
    this.clearError("setup")
  }

  toggleDropdown(event) {
    event.preventDefault()
    event.stopPropagation()

    const name = event.currentTarget.dataset.dropdownName
    const menu = this.dropdownMenuTargets.find((target) => target.dataset.dropdownName === name)
    if (!menu) return

    const shouldOpen = menu.classList.contains("hidden")
    this.closeDropdowns()

    if (shouldOpen) {
      menu.hidden = false
      menu.classList.remove("hidden")
    }
  }

  selectDropdown(event) {
    event.preventDefault()
    event.stopPropagation()

    const option = event.currentTarget
    const name = option.dataset.dropdownName
    const value = option.dataset.dropdownValue
    const label = option.dataset.dropdownLabel
    const inputTargetName = this.dropdownInputTarget(name)

    if (!inputTargetName || !value || !label) return

    this[inputTargetName + "Target"].value = value

    const labelTarget = this.dropdownLabelTargets.find(
      (target) => target.closest("[data-dropdown-name]")?.dataset.dropdownName === name
    )

    if (labelTarget) labelTarget.textContent = label

    this.updateDropdownOptions(name, value)

    const menu = option.closest('[data-registration-wizard-target="dropdownMenu"]')
    menu?.classList.add("hidden")
    if (menu) menu.hidden = true
    this.closeDropdowns()
  }

  dropdownInputTarget(name) {
    return {
      "business-sector": "businessSector",
      currency: "currency",
      terminals: "terminals",
      "payment-integration": "payments"
    }[name]
  }

  closeDropdowns() {
    this.dropdownMenuTargets.forEach((menu) => {
      menu.classList.add("hidden")
      menu.hidden = true
    })
  }

  selectVolume(event) {
    this.migrationVolumeTarget.value = event.currentTarget.value
  }

  selectPriority(event) {
    this.migrationPriorityTarget.value = event.currentTarget.value
  }

  syncBranches(event) {
    this.branchesHiddenTarget.value = event.currentTarget.value
  }

  togglePassword(event) {
    const field = event.currentTarget.closest(".relative")?.querySelector("input")
    if (!field) return
    field.type = field.type === "password" ? "text" : "password"
  }

  submit(event) {
    if (this.currentStep !== 5 || !this.validateStep()) {
      event.preventDefault()
    }
  }

  validateStep() {
    this.clearErrors()

    return {
      1: () => this.validateSetupType(),
      2: () => this.validateAdministrator(),
      3: () => this.validateCompany(),
      4: () => this.validateEnvironment(),
      5: () => this.validateTerms()
    }[this.currentStep]()
  }

  validateSetupType() {
    return this.selectedSetupType
      ? true
      : this.setError("setup", this.message("required"))
  }

  validateAdministrator() {
    const firstName = this.firstNameTarget.value.trim()
    const lastName = this.lastNameTarget.value.trim()
    const email = this.element.querySelector('input[name="user[email]"]')

    if (
      !firstName ||
      !lastName ||
      !email?.value.trim() ||
      !this.passwordTarget.value ||
      !this.confirmationTarget.value
    ) {
      return this.setError("setup", this.message("required"))
    }

    if (this.passwordTarget.value !== this.confirmationTarget.value) {
      return this.setError("setup", this.message("passwordMatch"))
    }

    return true
  }

  validateCompany() {
    if (!this.companyNameTarget.value.trim() || !this.taxIdTarget.value.trim()) {
      return this.setError("setup", this.message("required"))
    }

    const length = this.taxIdTarget.value.trim().length
    return length >= 12 && length <= 13
      ? true
      : this.setError("setup", this.message("taxId"))
  }

  validateEnvironment() {
    if (!this.businessSectorTarget.value) {
      return this.setError("setup", this.message("required"))
    }

    if (
      this.selectedSetupType === "migration" &&
      (!this.migrationVolumeTarget.value || !this.migrationPriorityTarget.value)
    ) {
      return this.setError("setup", this.message("required"))
    }

    const branches = Number(this.branchesHiddenTarget.value)
    return Number.isInteger(branches) && branches >= 1
      ? true
      : this.setError("setup", this.message("branches"))
  }

  validateTerms() {
    return this.termsTarget.checked
      ? true
      : this.setError("setup", this.message("terms"))
  }

  updateStep() {
    this.stepTargets.forEach((step) => {
      step.classList.toggle("hidden", Number(step.dataset.step) !== this.currentStep)
    })

    const progress = ((this.currentStep - 1) / 4) * 100
    this.progressTarget.style.width = `${progress}%`

    this.nodeTargets.forEach((node) => {
      const active = Number(node.dataset.step) <= this.currentStep
      node.classList.toggle("btn-delta-gradient", active)
      node.classList.toggle("text-white", active)
      node.classList.toggle("shadow-sm", active)
      node.classList.toggle("bg-slate-100", !active)
      node.classList.toggle("text-slate-400", !active)
    })

    this.stepCounterTarget.textContent = `${this.currentStep} / 5`
    this.backTarget.classList.toggle("hidden", this.currentStep === 1)
    this.nextTarget.classList.toggle("col-span-2", this.currentStep === 1)
    this.nextTarget.classList.toggle("col-start-2", this.currentStep !== 1)

    const label = this.nextTarget.querySelector("span")
    label.textContent = this.currentStep === 5
      ? this.nextTarget.dataset.submitLabel
      : this.nextTarget.dataset.nextLabel

    this.nextTarget.type = "button"

    if (this.currentStep === 4) {
      this.migrationFieldsTarget.classList.toggle("hidden", this.selectedSetupType !== "migration")
    }
  }

  updateSetupCards() {
    this.setupCardTargets.forEach((card) => {
      const selected = card.dataset.setupType === this.selectedSetupType

      card.classList.toggle("border-emerald-500", selected)
      card.classList.toggle("border-slate-100", !selected)
      card.classList.toggle("bg-emerald-50/40", selected)
      card.classList.toggle("bg-white", !selected)
      card.classList.toggle("shadow-md", selected)
      card.classList.toggle("shadow-sm", !selected)
      card.classList.toggle("ring-2", selected)
      card.classList.toggle("ring-emerald-500/20", selected)
      card.classList.toggle("ring-transparent", !selected)
      card.setAttribute("aria-pressed", selected.toString())
      card.dataset.selected = selected.toString()
    })

    this.migrationFieldsTarget.classList.toggle("hidden", this.selectedSetupType !== "migration")
  }

  setError(type, message) {
    const error = this.errorTargets.find((element) => element.dataset.error === type)
    if (!error) return false
    error.textContent = message
    error.classList.remove("hidden")
    return false
  }

  clearError(type) {
    this.errorTargets.find((element) => element.dataset.error === type)?.classList.add("hidden")
  }

  clearErrors() {
    this.errorTargets.forEach((error) => error.classList.add("hidden"))
  }

  message(key) {
    return this.wrapperTarget.dataset[`validation${key.charAt(0).toUpperCase() + key.slice(1)}`]
  }
}
