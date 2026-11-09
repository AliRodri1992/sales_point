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

    const size = this.selectTarget.value
    if (this.hasSummaryTarget && ["5", "10", "15", "25", "50"].includes(size)) {
      this.summaryTarget.textContent = this.templateValue.replace("__PAGE_SIZE__", size)
    }

    const hasChanges = this.recoveryValue || size !== this.originalValue
    if (this.hasSaveTarget) this.saveTarget.disabled = !hasChanges
    if (this.hasDirtyTarget) {
      this.dirtyTarget.textContent = hasChanges ? this.unsavedValue : this.unchangedValue
    }
  }
}
