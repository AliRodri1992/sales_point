import { Controller } from "@hotwired/stimulus"

// Keeps the illustrative table and the save state in sync with the native select.
export default class extends Controller {
  static targets = ["select", "summary", "save", "dirty"]
  static values = {
    template: String,
    original: String,
    recovery: Boolean,
    unsaved: String,
    unchanged: String
  }

  connect() {
    this.update()
  }

  update() {
    if (!this.hasSelectTarget) return

    const selectedSize = this.selectTarget.value
    const size = ["5", "10", "15", "25", "50"].includes(selectedSize) ? selectedSize : this.originalValue
    if (this.hasSummaryTarget) {
      this.summaryTarget.textContent = this.templateValue.replace("__PAGE_SIZE__", size)
    }

    const hasChanges = this.recoveryValue || selectedSize !== this.originalValue
    if (this.hasSaveTarget) this.saveTarget.disabled = !hasChanges
    if (this.hasDirtyTarget) {
      this.dirtyTarget.textContent = hasChanges ? this.unsavedValue : this.unchangedValue
    }
  }
}
