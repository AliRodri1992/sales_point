import { Controller } from "@hotwired/stimulus"

// Derive the key from the name until it is manually edited.
export default class extends Controller {
  static targets = [
    "name", "key", "category", "locale",
    "summaryName", "summaryKey", "summaryCategory", "summaryLocale"
  ]

  connect() {
    this.keyEdited = this.keyTarget.value.trim().length > 0
    this.updateSummary()
  }

  nameChanged() {
    if (!this.keyEdited) {
      this.keyTarget.value = this.nameTarget.value
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_+|_+$/g, "")
        .replace(/^[^a-z]+/, "")
        .slice(0, 100)
    }
    this.updateSummary()
  }

  keyChanged() {
    this.keyEdited = true
    this.updateSummary()
  }

  selectCategory(event) {
    if (!this.hasCategoryTarget) return
    this.categoryTarget.value = event.currentTarget.dataset.categoryValue
    this.categoryTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.categoryTarget.focus()
  }

  updateSummary() {
    if (this.hasSummaryNameTarget) this.summaryNameTarget.textContent = this.nameTarget.value.trim() || "—"
    if (this.hasSummaryKeyTarget) this.summaryKeyTarget.textContent = this.keyTarget.value.trim() || "—"
    if (this.hasSummaryCategoryTarget && this.hasCategoryTarget) {
      this.summaryCategoryTarget.textContent = this.categoryTarget.value.trim() || "—"
    }
    if (this.hasSummaryLocaleTarget && this.hasLocaleTarget) {
      const label = this.localeTarget.tagName === "SELECT"
        ? this.localeTarget.selectedOptions[0]?.textContent
        : this.localeTarget.textContent
      this.summaryLocaleTarget.textContent = label?.trim() || "—"
    }
  }
}
