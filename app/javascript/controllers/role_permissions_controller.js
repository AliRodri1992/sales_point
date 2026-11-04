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
      input.checked = event.target.checked
    })
    this.refresh()
  }

  refresh(event) {
    const code = event?.target?.dataset?.permissionCode
    const prefix = code?.split(".")[0]
    if (event?.target?.checked && ["languages", "products", "customers", "users", "categories"].includes(prefix)) {
      const access = this.permissionTargets.find(input => input.dataset.permissionCode === `${prefix}.access`)
      if (access) access.checked = true
    }
    this.totalTarget.textContent = String(this.permissionTargets.filter(input => input.checked).length)
    this.groupTargets.forEach(group => {
      const inputs = Array.from(group.querySelectorAll("[data-role-permissions-target='permission']"))
      const checked = inputs.filter(input => input.checked).length
      group.querySelector("[data-group-count]").textContent = String(checked)
      const select = group.querySelector("[data-select-group]")
      if (select) {
        select.checked = inputs.length > 0 && checked === inputs.length
        select.indeterminate = checked > 0 && checked < inputs.length
      }
    })
  }
}
