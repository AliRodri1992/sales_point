import { Controller } from "@hotwired/stimulus"

// A whole-day event spans midnight to the last minute of the chosen end date.
// Keep the original dates and never introduce radio controls inside dropdowns.
export default class extends Controller {
  static targets = ["allDay", "start", "end", "hint"]

  connect() { this.refresh() }

  refresh() {
    if (!this.hasAllDayTarget) return

    const allDay = this.allDayTarget.checked
    if (this.hasHintTarget) {
      this.hintTarget.textContent = allDay ? this.element.dataset.allDayHint || "" : ""
    }
    if (!allDay || !this.hasStartTarget || !this.hasEndTarget) return

    const startDate = this.startTarget.value.slice(0, 10)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate)) return

    const endDateInput = this.endTarget.value.slice(0, 10)
    const endDate = endDateInput && endDateInput >= startDate ? endDateInput : startDate
    this.startTarget.value = `${startDate}T00:00`
    this.endTarget.value = `${endDate}T23:59`
  }
}
