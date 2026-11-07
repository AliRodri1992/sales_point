import { Controller } from "@hotwired/stimulus"

// Insert a known placeholder at the caret and declare it before live preview.
export default class extends Controller {
  static targets = ["htmlBody", "variables"]

  connect() {
    this.activeField = this.hasHtmlBodyTarget ? this.htmlBodyTarget : null
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
    field.focus()
  }
}
