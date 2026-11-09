import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "group", "permission", "total", "empty", "results"]

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
    this.refresh()
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

    // Required access is explicit in the editor's help text and checked automatically.
    dependent.forEach(module => {
      const access = this.permissionTargets.find(permission => permission.dataset.permissionCode === `${module}.access`)
      if (!access) return
      if (this.permissionTargets.some(permission => permission.checked &&
          permission.dataset.permissionCode.startsWith(`${module}.`) && permission !== access)) {
        access.checked = true
      }
    })

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
