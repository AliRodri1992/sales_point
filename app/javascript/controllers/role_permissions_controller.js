import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "group", "permission", "total", "empty", "results", "dependencyNotice"]
  static values = { dependencyTemplate: String }

  connect() {
    this.filter()
  }

  normalize(value) {
    return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase()
  }

  filter() {
    const query = this.normalize(this.searchTarget.value.trim())
    let visible = 0
    this.groupTargets.forEach(group => {
      group.querySelectorAll("[data-permission-resource]").forEach(resource => {
        resource.querySelectorAll("[data-permission-row]").forEach(row => {
          row.hidden = !this.normalize(row.dataset.search).includes(query)
          if (!row.hidden) visible += 1
        })
        resource.hidden = !Array.from(resource.querySelectorAll("[data-permission-row]")).some(row => !row.hidden)
      })
      group.hidden = !Array.from(group.querySelectorAll("[data-permission-resource]")).some(resource => !resource.hidden)
      if (query && !group.hidden) group.open = true
    })
    this.emptyTarget.hidden = visible > 0
    this.resultsTarget.textContent = String(visible)
    this.refresh()
  }

  selectGroup(event) {
    const group = event.target.closest("[data-role-permissions-target='group']")
    group.querySelectorAll("[data-role-permissions-target='permission']:not(:disabled)").forEach(input => {
      if (!input.closest("[data-permission-row]").hidden) input.checked = event.target.checked
    })
    this.refresh(event)
  }

  refresh(event) {
    const input = event?.target
    const code = input?.dataset?.permissionCode
    const prefix = code?.split(".")[0]
    const dependent = ["languages", "products", "customers", "users", "categories"]

    if (code?.endsWith(".access") && !input.checked && dependent.includes(prefix)) {
      this.permissionTargets.forEach(permission => {
        if (permission.dataset.permissionCode.startsWith(`${prefix}.`)) permission.checked = false
      })
    }

    // Only reconcile actions just selected by the user, never alter saved roles on page load.
    const changedInputs = input?.hasAttribute("data-select-group") ?
      Array.from(input.closest("[data-role-permissions-target='group']")
        .querySelectorAll("[data-role-permissions-target='permission']"))
        .filter(permission => !permission.closest("[data-permission-row]").hidden && permission.checked) :
      [input].filter(Boolean)

    const autoSelected = []
    if (input?.checked) {
      changedInputs.forEach(permission => {
        const [module, action] = permission.dataset.permissionCode?.split(".") || []
        if (!dependent.includes(module) || !action || action === "access") return
        const access = this.permissionTargets.find(item => item.dataset.permissionCode === `${module}.access`)
        if (access && !access.disabled && !access.checked) {
          access.checked = true
          autoSelected.push(access.dataset.permissionCode)
        }
      })
    }
    if (input && this.hasDependencyNoticeTarget) {
      const unique = [...new Set(autoSelected)]
      this.dependencyNoticeTarget.hidden = unique.length === 0
      this.dependencyNoticeTarget.textContent = unique.length ?
        this.dependencyTemplateValue.replace("%{permissions}", unique.join(", ")) : ""
    }

    this.totalTarget.textContent = String(this.permissionTargets.filter(permission => permission.checked).length)
    this.groupTargets.forEach(group => {
      const inputs = Array.from(group.querySelectorAll("[data-role-permissions-target='permission']"))
      const checked = inputs.filter(permission => permission.checked).length
      group.querySelector("[data-group-count]").textContent = String(checked)
      const visibleInputs = inputs.filter(permission => !permission.closest("[data-permission-row]").hidden)
      const visibleChecked = visibleInputs.filter(permission => permission.checked).length
      const select = group.querySelector("[data-select-group]")
      if (select) {
        select.checked = visibleInputs.length > 0 && visibleChecked === visibleInputs.length
        select.indeterminate = visibleChecked > 0 && visibleChecked < visibleInputs.length
      }
    })
  }
}
