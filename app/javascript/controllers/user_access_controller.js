import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "summary"]

  connect() { this.summarize() }

  filter(event) {
    const term = this.normalize(event.target.value)
    this.roleTargets.forEach((role) => { role.hidden = !this.normalize(role.dataset.roleName).includes(term) })
  }

  normalize(value) { return value.trim().normalize("NFD").replace(/\p{Diacritic}/gu, "").toLocaleLowerCase() }

  updateBranchSummary(event) {
    const branch = event.target.closest("details")
    const count = branch.querySelectorAll('input[type="checkbox"]:checked').length
    const badge = branch.querySelector("[data-branch-count]")
    badge.textContent = String(count)
    badge.hidden = count === 0
  }

  summarize() {
    if (!this.hasSummaryTarget) return
    const selected = this.roleTargets.filter((role) => role.querySelector("input").checked)
    this.summaryTarget.textContent = selected.map((role) => role.dataset.roleName).join(" · ")
  }
}
