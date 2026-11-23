import { Controller } from "@hotwired/stimulus"

const GROUP = "[data-role-permissions-target~='group']"
const PERMISSION = "[data-role-permissions-target~='permission']"

export default class extends Controller {
  static targets = [
    "search", "group", "permission", "total", "progress", "empty", "results", "dependencyNotice", "stateFilter",
    "metadata", "pendingCount", "pendingDetails", "discard", "save", "dialog", "added", "addedList", "removed",
    "removedList", "noPermissionChanges", "reviewDetails", "tab", "panel", "tabCount", "pendingBreakdown",
    "saveCount", "discardDialog", "addedCount", "removedCount"
  ]
  static values = {
    dependencyTemplate: String, removedDependencyTemplate: String, savedPermissionIds: Array,
    initialTab: String, pendingBreakdownTemplate: String, savedLabel: String
  }

  connect() {
    this.selectFilter("all")
    this.filter()
    if (this.hasTabTarget) this.activateTab(this.initialTabValue)
    if (this.hasDialogTarget && typeof this.dialogTarget.showModal === "function") {
      this.savedPermissionIds = new Set(this.savedPermissionIdsValue.map(String))
      this.discardTarget.hidden = false
      this.refreshPending()
    }
  }

  differences() {
    const added = []
    const removed = []
    this.permissionTargets.forEach(input => {
      const saved = this.savedPermissionIds.has(input.value)
      if (input.checked && !saved) added.push(input)
      if (!input.checked && saved) removed.push(input)
    })
    const details = this.metadataTargets.some(input => input.value !== input.dataset.savedValue)
    return { added, removed, details }
  }

  refreshPending() {
    if (!this.savedPermissionIds) return

    const { added, removed, details } = this.differences()
    const count = String(added.length + removed.length)
    if (this.pendingCountTarget.textContent !== count) this.pendingCountTarget.textContent = count
    this.pendingDetailsTarget.hidden = !details
    const clean = count === "0" && !details
    this.pendingBreakdownTarget.textContent = clean ? this.savedLabelValue :
      this.pendingBreakdownTemplateValue.replace("%{added}", added.length).replace("%{removed}", removed.length)
    this.saveCountTarget.textContent = count
    this.saveCountTarget.hidden = count === "0"
    this.discardTarget.disabled = clean || this.submitting
    this.saveTarget.disabled = clean || this.submitting
  }

  discard() {
    if (this.submitting) return
    this.pendingDestination = null
    this.discardDialogTarget.showModal()
  }

  cancelDiscard(event) {
    event?.preventDefault()
    this.pendingDestination = null
    this.discardDialogTarget.close()
  }

  isDirty() {
    if (!this.savedPermissionIds || this.submitting || this.leaving) return false
    const { added, removed, details } = this.differences()
    return Boolean(added.length || removed.length || details)
  }

  guardNavigation(event) {
    if (!this.isDirty()) return
    event.preventDefault()
    this.pendingDestination = event.detail.url
    if (!this.discardDialogTarget.open) this.discardDialogTarget.showModal()
  }

  guardUnload(event) {
    if (!this.isDirty()) return
    event.preventDefault()
    event.returnValue = ""
  }

  confirmDiscard() {
    const destination = this.pendingDestination
    this.cancelDiscard()
    if (destination) {
      this.leaving = true
      window.location.assign(destination)
      return
    }

    this.permissionTargets.forEach(input => { input.checked = this.savedPermissionIds.has(input.value) })
    this.metadataTargets.forEach(input => { input.value = input.dataset.savedValue })
    this.dependencyNoticeTarget.textContent = ""
    this.filter()
    this.refreshPending()
    if (this.searchTarget.offsetParent) this.searchTarget.focus()
  }

  selectTab(event) {
    this.activateTab(event.currentTarget.getAttribute("aria-controls"))
  }

  activateTab(panelId, focus = false) {
    this.panelTargets.forEach(panel => { panel.hidden = panel.id !== panelId })
    this.tabTargets.forEach(tab => {
      const active = tab.getAttribute("aria-controls") === panelId
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
      if (active && focus) tab.focus()
    })
    this.refresh()
  }

  tabKeydown(event) {
    const index = this.tabTargets.indexOf(event.target)
    if (index === -1) return
    const last = this.tabTargets.length - 1
    const next = { ArrowRight: (index + 1) % (last + 1), ArrowLeft: (index + last) % (last + 1), Home: 0, End: last }[event.key]
    if (next === undefined) return
    event.preventDefault()
    this.activateTab(this.tabTargets[next].getAttribute("aria-controls"), true)
  }

  review(event) {
    if (!this.savedPermissionIds || this.confirming) return

    event.preventDefault()
    if (this.submitting || this.dialogTarget.open) return

    const { added, removed, details } = this.differences()
    this.renderReviewList(this.addedTarget, this.addedListTarget, added)
    this.renderReviewList(this.removedTarget, this.removedListTarget, removed)
    this.addedCountTarget.textContent = String(added.length)
    this.removedCountTarget.textContent = String(removed.length)
    this.noPermissionChangesTarget.hidden = added.length + removed.length > 0
    this.reviewDetailsTarget.hidden = !details
    this.dialogTarget.showModal()
  }

  renderReviewList(section, list, inputs) {
    section.hidden = inputs.length === 0
    list.replaceChildren(...inputs.map(input => {
      const item = document.createElement("li")
      const code = document.createElement("code")
      code.className = "break-all rounded bg-slate-100 px-1 font-mono text-xs"
      code.textContent = input.dataset.permissionCode
      item.append(input.dataset.permissionName, " ", code)
      return item
    }))
  }

  closeReview() {
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
    if (this.hasDiscardDialogTarget && this.discardDialogTarget.open) this.cancelDiscard()
  }

  confirm() {
    if (this.submitting || !this.dialogTarget.open) return

    this.closeReview()
    this.confirming = true
    this.submitting = true
    this.discardTarget.disabled = true
    try {
      this.element.requestSubmit(this.saveTarget)
    } finally {
      this.confirming = false
    }
  }

  submissionEnded(event) {
    if (!event.detail.success) this.submitting = false
    this.refreshPending()
  }

  normalize(value) {
    return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase()
  }

  filterState(event) {
    this.selectFilter(event.currentTarget.dataset.filterState)
    this.filter(true)
  }

  selectFilter(state) {
    this.filterStateValue = state
    this.stateFilterTargets.forEach(button => {
      button.setAttribute("aria-pressed", String(button.dataset.filterState === state))
    })
  }

  clearFilters() {
    this.searchTarget.value = ""
    this.selectFilter("all")
    this.filter(true)
    this.searchTarget.focus()
  }

  searchChanged() {
    this.filter(Boolean(this.searchTarget.value.trim()))
  }

  filter(expandMatches = false) {
    const query = this.normalize(this.searchTarget.value.trim())
    let visible = 0

    this.groupTargets.forEach(group => {
      let groupMatches = 0
      group.querySelectorAll("[data-permission-resource]").forEach(resource => {
        let resourceMatches = 0
        resource.querySelectorAll(PERMISSION).forEach(input => {
          const row = input.closest("[data-permission-row]")
          const stateMatches = this.filterStateValue === "all" ||
            input.checked === (this.filterStateValue === "assigned")
          row.hidden = !stateMatches || !this.normalize(row.dataset.search).includes(query)
          if (!row.hidden) resourceMatches += 1
        })
        resource.hidden = resourceMatches === 0
        groupMatches += resourceMatches
      })
      group.hidden = groupMatches === 0
      if (expandMatches && !group.hidden) group.open = true
      visible += groupMatches
    })

    this.emptyTarget.hidden = visible > 0
    this.resultsTarget.textContent = String(visible)
    this.refresh()
  }

  expandAll() {
    this.groupTargets.forEach(group => { group.open = true })
  }

  collapseAll() {
    this.groupTargets.forEach(group => { group.open = false })
  }

  setVisible(event) {
    const button = event.currentTarget
    const group = button.closest(GROUP)
    const checked = button.dataset.bulkState === "grant"
    const changes = this.visibleInputs(group).filter(input => input.checked !== checked)

    this.applyChanges(changes, checked)
    if (group.hidden) {
      this.focusFilter()
    } else if (button.disabled) {
      const next = group.querySelector("[data-bulk-state]:enabled") || group.querySelector("summary")
      next.focus({ preventScroll: true })
    }
  }

  permissionChanged(event) {
    const input = event.currentTarget
    this.applyChanges([input], input.checked)
    if (!input.closest("[data-permission-row]").hidden) return

    const group = input.closest(GROUP)
    if (group.hidden) {
      this.focusFilter()
    } else {
      const next = this.visibleInputs(group)[0] || group.querySelector("summary")
      next.focus()
    }
  }

  applyChanges(inputs, checked) {
    inputs.forEach(input => { input.checked = checked })
    const automatic = this.reconcileDependencies(inputs, checked)
    const template = checked ? this.dependencyTemplateValue : this.removedDependencyTemplateValue
    this.dependencyNoticeTarget.textContent = automatic.size ?
      template.replace("%{permissions}", [...automatic].join(", ")) : ""
    this.filter()
    this.dispatch("selection-changed")
  }

  reconcileDependencies(inputs, checked) {
    const automatic = new Set()

    inputs.forEach(input => {
      const accessCode = input.dataset.permissionAccess
      if (!accessCode) return

      if (checked) {
        const access = this.permissionTargets.find(permission => permission.dataset.permissionCode === accessCode)
        if (access && !access.matches(":disabled") && !access.checked) {
          access.checked = true
          automatic.add(accessCode)
        }
      } else if (input.dataset.permissionCode === accessCode) {
        this.permissionTargets.forEach(permission => {
          if (permission.dataset.permissionAccess !== accessCode || permission.matches(":disabled") || !permission.checked) return

          permission.checked = false
          automatic.add(permission.dataset.permissionCode)
        })
      }
    })

    return automatic
  }

  visibleInputs(group) {
    return Array.from(group.querySelectorAll(PERMISSION)).filter(input => !input.closest("[hidden]") && !input.matches(":disabled"))
  }

  focusFilter() {
    this.stateFilterTargets.find(button => button.dataset.filterState === this.filterStateValue)?.focus()
  }

  refresh() {
    const selected = this.permissionTargets.filter(input => input.checked).length
    this.totalTarget.textContent = String(selected)
    if (this.hasTabCountTarget) this.tabCountTarget.textContent = String(selected)
    if (this.hasProgressTarget) this.progressTarget.value = selected

    this.groupTargets.forEach(group => {
      const selectedInGroup = group.querySelectorAll(`${PERMISSION}:checked`).length
      group.querySelector("[data-group-count]").textContent = String(selectedInGroup)
      group.querySelectorAll("[data-resource-count]").forEach(count => {
        count.textContent = String(count.closest("[data-permission-resource]").querySelectorAll(`${PERMISSION}:checked`).length)
      })
      const grant = group.querySelector("[data-bulk-state='grant']")
      const revoke = group.querySelector("[data-bulk-state='revoke']")
      if (!grant || !revoke) return

      const visible = this.visibleInputs(group)
      grant.disabled = !visible.some(input => !input.checked)
      revoke.disabled = !visible.some(input => input.checked)
    })
  }
}
