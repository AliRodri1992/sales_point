import { Controller } from "@hotwired/stimulus"

// Accessible supplier dossier navigation; one Rails form, one submission.
export default class extends Controller {
  static targets = ["step", "tab", "circle", "previous", "next"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    const invalid = this.stepTargets.findIndex((step) => step.querySelector(".text-red-600, .text-rose-600, [aria-invalid='true'], .field_with_errors"))
    if (invalid >= 0) this.indexValue = invalid
    this.render()
  }

  select(event) {
    this.indexValue = Number(event.currentTarget.dataset.stepIndex)
  }

  next() {
    this.indexValue = Math.min(this.indexValue + 1, this.stepTargets.length - 1)
  }

  previous() {
    this.indexValue = Math.max(this.indexValue - 1, 0)
  }

  indexValueChanged() {
    if (this.hasStepTarget) this.render()
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
    if (this.hasPreviousTarget) this.previousTarget.hidden = this.indexValue === 0
    if (this.hasNextTarget) this.nextTarget.hidden = this.indexValue === this.stepTargets.length - 1
  }
}
