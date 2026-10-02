import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "wrapper",
    "step",
    "node",
    "progress",
    "stepCounter",
    "setupType",
    "setupCard",
    "businessSector",
    "migrationVolume",
    "migrationPriority",
    "branchesHidden",
    "currency",
    "terminals",
    "payments",
    "migrationFields",
    "terms",
    "back",
    "next",
    "error",
    "companyName",
    "taxId",
    "input",
    "password",
    "confirmation"
  ]

  connect() {
    this.currentStep = 1
    this.selectedSetupType = this.setupTypeTarget.value || "new"
    this.updateSetupCards()
    this.updateStep()
  }

  next() {
    if (!this.validateStep()) return
    if (this.currentStep < 5) {
      this.currentStep += 1
      this.updateStep()
    }
  }

  previous() {
    if (this.currentStep <= 1) return
    this.currentStep -= 1
    this.updateStep()
  }

  selectSetup(event) {
    event.preventDefault()
    this.selectedSetupType = event.currentTarget.dataset.setupType
    this.setupTypeTarget.value = this.selectedSetupType
    this.updateSetupCards()
    this.clearError("setup")
  }

  selectBusiness(event) {
    this.businessSectorTarget.value = event.currentTarget.value
  }

  selectVolume(event) {
    this.migrationVolumeTarget.value = event.currentTarget.value
  }

  selectPriority(event) {
    this.migrationPriorityTarget.value = event.currentTarget.value
  }

  selectCurrency(event) {
    this.currencyTarget.value = event.currentTarget.value
  }

  syncBranches(event) {
    this.branchesHiddenTarget.value = event.currentTarget.value
  }

  selectTerminals(event) {
    this.terminalsTarget.value = event.currentTarget.value
  }

  selectPayments(event) {
    this.paymentsTarget.value = event.currentTarget.value
  }

  togglePassword(event) {
    const wrapper = event.currentTarget.closest(".relative")
    const field = wrapper?.querySelector("input")
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

    caseValue = this.currentStep

    if (caseValue === 1) {
      return Boolean(this.setupTypeTarget.value)
    }

    if (caseValue === 2) {
      const name = this.inputTargets.find((input) => input.name === "user[username]")
      const email = this.inputTargets.find((input) => input.name === "user[email]")
      const password = this.passwordTarget
      const confirmation = this.confirmationTarget

      if (!name?.value.trim() || !email?.value.trim() || !password?.value || !confirmation?.value) {
        return this.setError("setup", "<%= t(".client_validation_required") %>")
      }

      if (password.value !== confirmation.value) {
        return this.setError("setup", "<%= t(".client_validation_password_match") %>")
      }

      return true
    }

    if (caseValue === 3) {
      if (!this.companyNameTarget.value.trim() || !this.taxIdTarget.value.trim()) {
        return this.setError("setup", "<%= t(".client_validation_required") %>")
      }

      const taxIdLength = this.taxIdTarget.value.trim().length
      if (taxIdLength < 12 || taxIdLength > 13) {
        return this.setError("setup", "<%= t(".client_validation_tax_id") %>")
      }

      return true
    }

    if (caseValue === 4) {
      if (!this.businessSectorTarget.value) {
        return this.setError("setup", "<%= t(".client_validation_required") %>")
      }

      if (this.selectedSetupType === "migration" &&
          (!this.migrationVolumeTarget.value || !this.migrationPriorityTarget.value)) {
        return this.setError("setup", "<%= t(".client_validation_required") %>")
      }

      const branches = Number(this.branchesHiddenTarget.value)
      if (!Number.isInteger(branches) || branches < 1) {
        return this.setError("setup", "<%= t(".client_validation_branches") %>")
      }

      return true
    }

    if (!this.termsTarget.checked) {
      return this.setError("terms", "<%= t(".client_validation_terms") %>")
    }

    return true
  }

  updateStep() {
    this.stepTargets.forEach((step) => {
      step.classList.toggle("hidden", Number(step.dataset.step) !== this.currentStep)
    })

    const progress = ((this.currentStep - 1) / 4) * 100
    this.progressTarget.style.width = `calc(${progress}% - ${progress ? 0 : 0}px)`

    this.nodeTargets.forEach((node) => {
      const active = Number(node.dataset.step) <= this.currentStep
      node.classList.toggle("border-emerald-600", active)
      node.classList.toggle("bg-emerald-600", active)
      node.classList.toggle("text-white", active)
      node.classList.toggle("border-slate-200", !active)
      node.classList.toggle("text-slate-400", !active)
    })

    this.stepCounterTarget.textContent = `${this.currentStep} / 5`
    this.backTarget.classList.toggle("hidden", this.currentStep === 1)

    const nextLabel = this.nextTarget.querySelector("span")
    nextLabel.textContent = this.currentStep === 5
      ? this.nextTarget.dataset.submitLabel
      : this.nextTarget.dataset.nextLabel

    this.nextTarget.type = this.currentStep === 5 ? "submit" : "button"

    if (this.currentStep === 4) {
      this.migrationFieldsTarget.classList.toggle("hidden", this.selectedSetupType !== "migration")
    }
  }

  updateSetupCards() {
    this.setupCardTargets.forEach((card) => {
      const selected = card.dataset.setupType === this.selectedSetupType
      card.classList.toggle("border-emerald-500", selected)
      card.classList.toggle("bg-emerald-50/40", selected)
      card.classList.toggle("border-slate-200", !selected)
      card.setAttribute("aria-pressed", selected)
    })

    if (this.hasMigrationFieldsTarget) {
      this.migrationFieldsTarget.classList.toggle("hidden", this.selectedSetupType !== "migration")
    }
  }

  setError(type, message) {
    const error = this.errorTargets.find((element) => element.dataset.error === type)
    if (!error) return false
    error.textContent = message
    error.classList.remove("hidden")
    return false
  }

  clearError(type) {
    const error = this.errorTargets.find((element) => element.dataset.error === type)
    error?.classList.add("hidden")
  }

  clearErrors() {
    this.errorTargets.forEach((error) => error.classList.add("hidden"))
  }
}
