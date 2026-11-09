import { Controller } from "@hotwired/stimulus"

// The sample rows are illustrative; only the page-size caption is dynamic.
export default class extends Controller {
  static targets = ["select", "summary"]
  static values = { template: String }

  connect() {
    this.update()
  }

  update() {
    if (!this.hasSelectTarget || !this.hasSummaryTarget) return

    const size = this.selectTarget.value
    if (!["5", "10", "15", "25", "50"].includes(size)) return

    this.summaryTarget.textContent = this.templateValue.replace("__PAGE_SIZE__", size)
  }
}
