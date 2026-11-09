import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "role", "summary", "empty", "submitButton", "email", "username",
    "userType", "language", "theme", "themeSwatch", "themeLabel",
    "employeeRolesRequired", "employeeRoleScreenReader",
    "branchRole", "roleWarning",
    "reviewEmail", "reviewUsername", "reviewUserType", "reviewLanguage",
    "reviewTheme", "reviewRoles", "reviewBranches"
  ]

  connect() {
    this.summarize()
    this.updateReview()
    // Model errors are authoritative; move both focus and the viewport to the first invalid field.
    const invalidField = this.element.querySelector('[aria-invalid="true"], [data-user-access-error-group]')
    if (invalidField) {
      invalidField.closest("details")?.setAttribute("open", "")
      invalidField.focus()
    }
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
    const selected = this.selectedRoles()
    this.summaryTarget.textContent = selected.length === 0
      ? this.summaryTarget.dataset.emptyLabel
      : `${this.summaryTarget.dataset.selectedLabel} (${selected.length}): ${selected.map((role) => role.dataset.roleName).join(" · ")}`
    this.updateReview()
  }

  selectedRoles() {
    return this.roleTargets.filter((role) => role.querySelector("input")?.checked)
  }

  formChanged() {
    this.updateReview()
  }

  updateReview() {
    const empty = this.element.dataset.emptyValue || "—"
    const update = (targetName, value) => {
      const accessor = targetName[0].toUpperCase() + targetName.slice(1)
      if (this[`has${accessor}Target`]) this[`${targetName}Target`].textContent = value || empty
    }
    if (this.hasEmailTarget) update("reviewEmail", this.emailTarget.value.trim())
    if (this.hasUsernameTarget) update("reviewUsername", this.usernameTarget.value.trim())
    if (this.hasUserTypeTarget) update("reviewUserType", this.selectedLabel(this.userTypeTarget))
    if (this.hasLanguageTarget) update("reviewLanguage", this.selectedLabel(this.languageTarget))
    if (this.hasThemeTarget) {
      const option = this.themeTarget.selectedOptions[0]
      update("reviewTheme", this.selectedLabel(this.themeTarget))
      if (this.hasThemeLabelTarget) this.themeLabelTarget.textContent = option?.textContent?.trim() || empty
      if (this.hasThemeSwatchTarget) {
        this.themeSwatchTarget.style.backgroundColor = option?.dataset.swatchColor || "transparent"
      }
    }
    const roles = this.selectedRoles()
    update("reviewRoles", roles.length > 0 ? roles.map((role) => role.dataset.roleName).join(" · ") : "")
    const employee = this.hasUserTypeTarget && this.userTypeTarget.value === "employee"
    if (this.hasEmployeeRolesRequiredTarget) this.employeeRolesRequiredTarget.classList.toggle("hidden", !employee)
    if (this.hasEmployeeRoleScreenReaderTarget) this.employeeRoleScreenReaderTarget.classList.toggle("hidden", !employee)
    if (this.hasRoleWarningTarget) {
      this.roleWarningTarget.textContent = employee
        ? this.roleWarningTarget.dataset.employeeMessage
        : this.roleWarningTarget.dataset.optionalMessage
      this.roleWarningTarget.classList.toggle(
        "hidden", roles.length > 0 || this.branchRoleTargets.some((input) => input.checked)
      )
    }
    const branchNames = [...new Set(this.branchRoleTargets.filter((input) => input.checked)
      .map((input) => input.closest("details")?.querySelector("summary span.flex-1")?.textContent?.trim())
      .filter(Boolean))]
    update("reviewBranches", branchNames.join(" · "))
  }

  selectedLabel(select) {
    const option = select.selectedOptions[0]
    return option?.value ? option.textContent.trim() : ""
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
