import { Controller } from "@hotwired/stimulus"

// Insert a known placeholder at the caret and declare it before live preview.
export default class extends Controller {
  static targets = ["htmlBody", "variables", "variablePills"]

  connect() {
    this.activeField = this.hasHtmlBodyTarget ? this.htmlBodyTarget : null
    this.renderDeclaredVariables()
  }

  rememberField(event) {
    this.activeField = event.currentTarget
  }

  insertVariable(event) {
    const variable = event.currentTarget.dataset.variable
    const field = this.activeField || (this.hasHtmlBodyTarget ? this.htmlBodyTarget : null)
    if (!variable || !field || !this.hasVariablesTarget) return

    const marker = `{{${variable}}}`
    const start = field.selectionStart ?? field.value.length
    const end = field.selectionEnd ?? start
    field.setRangeText(marker, start, end, "end")

    const names = this.variablesTarget.value.split(",").map((name) => name.trim()).filter(Boolean)
    if (!names.includes(variable)) {
      names.push(variable)
      this.variablesTarget.value = names.join(", ")
    }
    field.dispatchEvent(new Event("input", { bubbles: true }))
    this.variablesTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.renderDeclaredVariables()
    field.focus()
  }

  renderDeclaredVariables() {
    if (!this.hasVariablesTarget || !this.hasVariablePillsTarget) return

    const names = [...new Set(this.variablesTarget.value.split(",").map(v => v.trim()).filter(Boolean))]
    const pills = names.map(name => {
      const pill = document.createElement("span")
      pill.className = "inline-flex items-center rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-1 font-mono text-[11px] font-semibold text-emerald-800"
      pill.textContent = name
      return pill
    })
    this.variablePillsTarget.replaceChildren(...pills)
  }
}
