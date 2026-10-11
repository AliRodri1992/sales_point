import { Controller } from "@hotwired/stimulus"

// Accessible supplier dossier navigation; one Rails form, one submission.
export default class extends Controller {
  static targets = ["step", "tab", "circle", "previous", "next", "submit", "summary"]
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

  submit(event) {
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
