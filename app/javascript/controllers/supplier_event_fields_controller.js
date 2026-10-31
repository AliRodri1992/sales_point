import { Controller } from "@hotwired/stimulus"

// Keep date and time fields available for multi-day events, while explaining
// the all-day convention. This controller never adds radio controls to selects.
export default class extends Controller {
  static targets = ["allDay", "start", "end", "hint"]

  connect() { this.refresh() }

  refresh() {
    if (!this.hasAllDayTarget) return
    const allDay = this.allDayTarget.checked
    if (this.hasHintTarget) this.hintTarget.textContent = allDay ? this.element.dataset.allDayHint || "" : ""
    if (!allDay || !this.hasStartTarget || !this.hasEndTarget) return

    const start = this.startTarget.value
    const end = this.endTarget.value
    if (!start) return

    // Preserve the selected date range rather than forcing a single day.
    const startDate = start.slice(0, 10)
    const endDate = end ? end.slice(0, 10) : startDate
    const endTime = end ? end.slice(11, 16) : ""
    if (!end || endTime === "00:00") {
      this.endTarget.value = `${endDate}T23:59`
      this.endTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }
}
