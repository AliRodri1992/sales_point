import { Controller } from "@hotwired/stimulus"

// Accessible supplier dossier navigation; one Rails form, one submission.
export default class extends Controller {
  static targets = ["step", "tab", "circle", "previous", "next", "submit", "summary"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.element.addEventListener("input", (event) => {
      if (event.target.matches("input[required], select[required], textarea[required]")) this.validateField(event.target)
    })
    this.element.addEventListener("change", (event) => {
      if (event.target.matches("input[required], select[required], textarea[required]")) this.validateField(event.target)
    })
    const invalid = this.stepTargets.findIndex((step) => step.querySelector(".text-red-600, .text-rose-600, [aria-invalid='true'], .field_with_errors"))
    if (invalid >= 0) this.indexValue = invalid
    this.render()
  }

  fieldWrapper(field) {
    return field.closest("[data-controller='international-phone']")?.parentElement || field.closest(".grid > div") || field.parentElement
  }

  clearFieldError(field) {
    field.removeAttribute("aria-invalid")
    field.classList.remove("border-rose-500", "bg-rose-50")
    this.fieldWrapper(field)?.querySelector("[data-required-error]")?.remove()
  }

  showFieldError(field) {
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
    const template = this.element.dataset.requiredMessage || "%{field} is required"
    message.textContent = template.replace("%{field}", label)
  }

  validateField(field) {
    const valid = field.value.trim().length > 0 && field.validity.valid
    if (valid) this.clearFieldError(field)
    else this.showFieldError(field)
    return valid
  }

  select(event) {
    const destination = Number(event.currentTarget.dataset.stepIndex)
    if (destination > this.indexValue && !this.validateThrough(destination)) return
    this.indexValue = destination
  }

  next() {
    if (!this.validateStep(this.indexValue)) return
    this.indexValue = Math.min(this.indexValue + 1, this.stepTargets.length - 1)
  }

  submit(event) {
    if (!this.validateThrough(this.stepTargets.length - 1)) {
      event.preventDefault()
      return
    }
    if (this.indexValue !== this.stepTargets.length - 1) {
      event.preventDefault()
      this.indexValue = this.stepTargets.length - 1
    }
  }

  previous() {
    this.indexValue = Math.max(this.indexValue - 1, 0)
  }

  indexValueChanged() {
    if (this.hasStepTarget) this.render()
  }

  validateThrough(destination) {
    for (let index = 0; index < destination; index += 1) {
      if (!this.validateStep(index)) {
        this.indexValue = index
        return false
      }
    }
    return true
  }

  validateStep(index) {
    const step = this.stepTargets[index]
    const fields = [...step.querySelectorAll("input[required], select[required], textarea[required]")]
    const invalid = fields.filter((field) => !this.validateField(field))
    if (!invalid.length) return true

    this.indexValue = index
    this.render()
    invalid[0].focus()
    return false
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return
    this.summaryTarget.replaceChildren()
    this.stepTargets.slice(0, -1).forEach((step) => {
      const entries = [...step.querySelectorAll("input, select, textarea")].filter((field) =>
        field.name && !["hidden", "submit", "button"].includes(field.type) && !field.disabled
      ).map((field) => {
        const label = field.labels?.[0]?.textContent?.trim() || field.name.split("[").pop().replace("]", "")
        let value = field.value
        if (field.type === "file") value = [...field.files].map((file) => file.name).join(", ")
        else if (field.tagName === "SELECT") value = field.selectedOptions[0]?.textContent?.trim() || ""
        else if (field.type === "checkbox" || field.type === "radio") value = field.checked ? field.value : ""
        return { label, value: value.trim() }
      }).filter(({ value }) => value)
      if (!entries.length) return
      const group = document.createElement("section")
      group.className = "rounded-xl border border-slate-200 bg-slate-50/50 p-4"
      const heading = document.createElement("h3")
      heading.className = "mb-3 text-sm font-bold text-slate-900"
      heading.textContent = step.querySelector("h2")?.textContent?.trim() || ""
      group.append(heading)
      const list = document.createElement("dl")
      list.className = "grid gap-3 sm:grid-cols-2"
      entries.forEach(({ label, value }) => {
        const item = document.createElement("div")
        const term = document.createElement("dt")
        term.className = "text-xs font-semibold text-slate-500"
        term.textContent = label
        const description = document.createElement("dd")
        description.className = "mt-1 break-words text-sm text-slate-900"
        description.textContent = value
        item.append(term, description)
        list.append(item)
      })
      group.append(list)
      this.summaryTarget.append(group)
    })
  }

  render() {
    this.stepTargets.forEach((step, index) => {
      step.hidden = index !== this.indexValue
      step.classList.toggle("hidden", index !== this.indexValue)
    })
    this.tabTargets.forEach((tab, index) => {
      const active = index === this.indexValue
      tab.setAttribute("aria-current", active ? "step" : "false")
      tab.classList.toggle("bg-emerald-50", active)
      tab.classList.toggle("text-emerald-800", active)
      tab.classList.toggle("border-emerald-500", active)
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
    if (this.indexValue === this.stepTargets.length - 1) this.updateSummary()
    if (this.hasSubmitTarget) this.submitTarget.hidden = this.indexValue !== this.stepTargets.length - 1
    if (this.hasPreviousTarget) this.previousTarget.hidden = this.indexValue === 0
    if (this.hasNextTarget) this.nextTarget.hidden = this.indexValue === this.stepTargets.length - 1
  }
}
