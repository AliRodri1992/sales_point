import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "node", "progress", "form", "businessType", "businessError",
    "branches", "branchesError", "terms", "termsError", "themeDropdown",
    "nameError", "emailError", "phoneError"
  ]

  static values = { paletteOnly: Boolean }

  connect() {
    this.currentStep = this.initialStep()
    document.addEventListener("click", this.closeOnOutsideClick)
    this.renderStep()
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  initialStep() {
    if (this.paletteOnlyValue) return 1

    const [stepOne, stepTwo] = this.stepTargets
    if (stepTwo?.querySelector(".text-rose-500:not(.hidden), .text-rose-600:not(.hidden)")) return 2
    if (stepOne?.querySelector(".text-rose-500:not(.hidden), .text-rose-600:not(.hidden)")) return 1

    return 1
  }

  next(event) {
    event.preventDefault()
    if (this.validateStepOne()) this.currentStep = 2
    this.renderStep()
  }

  back(event) {
    event.preventDefault()
    this.currentStep = 1
    this.renderStep()
  }

  submit(event) {
    if (this.paletteOnlyValue) return

    this.clearBusinessErrors()
    if (!this.validateStepTwo()) {
      event.preventDefault()
      this.renderStep()
    }
  }

  validateStepOne() {
    let valid = true
    const fields = [
      ["name", this.nameErrorTarget],
      ["email", this.emailErrorTarget],
      ["phone", this.phoneErrorTarget]
    ]

    fields.forEach(([field, errorTarget]) => {
      const input = this.formTarget.querySelector(`#demo_request_${field}`)
      errorTarget.classList.add("hidden")
      if (input && !input.value.trim()) {
        errorTarget.classList.remove("hidden")
        errorTarget.textContent = input.dataset.requiredMessage
        valid = false
      }
    })

    return valid
  }

  validateStepTwo() {
    let valid = true
    if (!this.businessTypeTarget.value) {
      this.showError(this.businessErrorTarget)
      valid = false
    }
    if (!this.branchesTarget.value || Number(this.branchesTarget.value) < 1) {
      this.showError(this.branchesErrorTarget)
      valid = false
    }
    if (!this.termsTarget.checked) {
      this.showError(this.termsErrorTarget)
      valid = false
    }
    return valid
  }

  showError(target) {
    target.classList.remove("hidden")
  }

  clearBusinessErrors() {
    [this.businessErrorTarget, this.branchesErrorTarget, this.termsErrorTarget].forEach((target) => {
      target.classList.add("hidden")
    })
  }

  renderStep() {
    if (this.paletteOnlyValue) return

    this.stepTargets.forEach((step) => {
      step.classList.toggle("hidden", Number(step.dataset.step) !== this.currentStep)
    })
    this.progressTarget.style.width = this.currentStep === 1 ? "0%" : "100%"

    this.nodeTargets.forEach((node) => {
      const active = Number(node.dataset.step) <= this.currentStep
      node.classList.toggle("bg-slate-100", !active)
      node.classList.toggle("text-slate-400", !active)
      node.classList.toggle("bg-[var(--demo-primary-start)]", active)
      node.classList.toggle("text-white", active)
      node.setAttribute("aria-current", Number(node.dataset.step) === this.currentStep ? "step" : "false")
    })
  }

  toggleTheme(event) {
    event.stopPropagation()
    this.themeDropdownTarget.classList.toggle("hidden")
  }

  selectTheme(event) {
    event.stopPropagation()
    document.documentElement.style.setProperty("--demo-primary-start", event.currentTarget.dataset.start)
    document.documentElement.style.setProperty("--demo-primary-end", event.currentTarget.dataset.end)
    this.themeDropdownTarget.classList.add("hidden")
  }

  closeOnOutsideClick = (event) => {
    if (!this.paletteOnlyValue || this.element.contains(event.target)) return
    this.themeDropdownTarget.classList.add("hidden")
  }
}
