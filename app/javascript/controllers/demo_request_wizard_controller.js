import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "node", "progress", "form", "businessType", "businessError",
    "branches", "branchesError", "terms", "termsError", "themeDropdown",
    "nameError", "emailError", "phoneError", "success"
  ]

  static values = { paletteOnly: Boolean }

  connect() {
    this.currentStep = this.initialStep()
    if (this.hasSuccessTarget) requestAnimationFrame(() => this.successTarget.focus())
    document.addEventListener("click", this.closeOnOutsideClick)
    this.renderStep()
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  initialStep() {
    if (this.paletteOnlyValue || !this.hasFormTarget) return 1

    const [stepOne, stepTwo] = this.stepTargets
    if (stepTwo?.querySelector('[aria-invalid="true"]')) return 2
    if (stepOne?.querySelector('[aria-invalid="true"]')) return 1

    return 1
  }

  next(event) {
    event.preventDefault()
    const valid = this.validateStepOne()

    if (valid) {
      this.currentStep = 2
    } else {
      this.showValidationAlert()
    }

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
    if (this.paletteOnlyValue || !this.hasFormTarget) return

    this.clearBusinessErrors()
    const stepOneValid = this.validateStepOne()
    const stepTwoValid = this.validateStepTwo()

    if (!stepOneValid || !stepTwoValid) {
      event.preventDefault()
      this.currentStep = stepOneValid ? 2 : 1
      this.renderStep()
      this.showValidationAlert()
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
        errorTarget.textContent = errorTarget.dataset.requiredMessage
        input.setAttribute("aria-invalid", "true")
        valid = false
      } else if (input && field === "email" && !this.validEmail(input.value)) {
        errorTarget.classList.remove("hidden")
        errorTarget.textContent = errorTarget.dataset.invalidMessage
        input.setAttribute("aria-invalid", "true")
        valid = false
      } else if (input && field === "phone" && input.dataset.valid !== "true") {
        errorTarget.classList.remove("hidden")
        errorTarget.textContent = errorTarget.dataset.invalidMessage
        input.setAttribute("aria-invalid", "true")
        valid = false
      } else if (input) {
        errorTarget.classList.add("hidden")
        input.removeAttribute("aria-invalid")
      }
    })

    return valid
  }

  validEmail(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())
  }

  showValidationAlert() {
    if (!window.Swal) return

    window.Swal.fire({
      toast: true,
      icon: "warning",
      position: "top-end",
      timer: 3200,
      timerProgressBar: true,
      showConfirmButton: false,
      title: this.formTarget.dataset.validationTitle
    })
  }

  validateStepTwo() {
    let valid = true
    if (!this.businessTypeTarget.value) {
      this.showError(this.businessTypeTarget, this.businessErrorTarget, this.businessErrorTarget.dataset.requiredMessage)
      valid = false
    }
    const branchesValue = Number(this.branchesTarget.value)
    if (!this.branchesTarget.value || !Number.isInteger(branchesValue) || branchesValue < 1 || branchesValue > Number(this.branchesTarget.max)) {
      this.showError(this.branchesTarget, this.branchesErrorTarget, this.branchesErrorTarget.dataset.requiredMessage)
      valid = false
    }
    if (!this.termsTarget.checked) {
      this.showError(this.termsTarget, this.termsErrorTarget, this.termsErrorTarget.dataset.requiredMessage)
      valid = false
    }
    return valid
  }

  showError(input, target, message) {
    target.textContent = message
    target.classList.remove("hidden")
    input.setAttribute("aria-invalid", "true")
  }

  clearFieldError(input, target) {
    target.textContent = ""
    target.classList.add("hidden")
    input.setAttribute("aria-invalid", "false")
  }

  clearBusinessErrors() {
    this.clearFieldError(this.businessTypeTarget, this.businessErrorTarget)
    this.clearFieldError(this.branchesTarget, this.branchesErrorTarget)
    this.clearFieldError(this.termsTarget, this.termsErrorTarget)
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
    const { start, end } = event.currentTarget.dataset
    const root = document.documentElement

    root.style.setProperty("--demo-primary-start", start)
    root.style.setProperty("--demo-primary-end", end)
    root.style.setProperty("--theme-hover-start", `color-mix(in srgb, ${start} 88%, black)`)
    root.style.setProperty("--theme-hover-end", `color-mix(in srgb, ${end} 88%, black)`)
    root.style.setProperty("--theme-active-start", `color-mix(in srgb, ${start} 76%, black)`)
    root.style.setProperty("--theme-active-end", `color-mix(in srgb, ${end} 76%, black)`)
    this.themeDropdownTarget.classList.add("hidden")
  }

  closeOnOutsideClick = (event) => {
    if (!this.paletteOnlyValue || this.element.contains(event.target)) return
    this.themeDropdownTarget.classList.add("hidden")
  }
}
