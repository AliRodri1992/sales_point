import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "summary", "empty", "submitButton"]

  connect() {
    this.summarize()
  }

  filter(event) {
    const term = this.normalize(event.target.value)
    let visible = 0
    this.roleTargets.forEach((role) => {
      const matches = this.normalize(role.dataset.roleName || "").includes(term)
      role.hidden = !matches
      if (matches) visible += 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visible > 0)
  }

  normalize(value) {
    return String(value).trim().normalize("NFD").replace(/\p{Diacritic}/gu, "").toLocaleLowerCase()
  }

  updateBranchSummary(event) {
    const branch = event.target.closest("details")
    if (!branch) return
    const count = branch.querySelectorAll('input[type="checkbox"]:checked').length
    const badge = branch.querySelector("[data-branch-count]")
    if (!badge) return
    badge.textContent = String(count)
    badge.hidden = count === 0
  }

  summarize() {
    if (!this.hasSummaryTarget) return
    const selected = this.roleTargets.filter((role) => role.querySelector("input")?.checked)
    const label = selected.length === 0
      ? this.summaryTarget.dataset.emptyLabel
      : `${this.summaryTarget.dataset.selectedLabel} (${selected.length}): ${selected.map((role) => role.dataset.roleName).join(" · ")}`
    this.summaryTarget.textContent = label
  }

  submit() {
    if (!this.hasSubmitButtonTarget || this.submitting) return
    this.submitting = true
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.setAttribute("aria-disabled", "true")
  }

  resetSubmission() {
    this.submitting = false
    if (!this.hasSubmitButtonTarget) return
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.removeAttribute("aria-disabled")
  }
}
