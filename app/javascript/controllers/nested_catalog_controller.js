import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  add(event) {
    const group = event.currentTarget.closest("[data-nested-catalog-group]")
    const rows = group.querySelector("[data-nested-catalog-rows]")
    if (rows.children.length >= Number(group.dataset.nestedCatalogLimit || 50)) return
    const template = group.querySelector("template").innerHTML
    rows.insertAdjacentHTML("beforeend", template.replaceAll("NEW_RECORD", String(this.sequence = (this.sequence || Date.now()) + 1)))
    rows.lastElementChild.querySelector("input:not([type=hidden]),select")?.focus()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-nested-catalog-row]")
    const destroy = row.querySelector("[data-nested-catalog-destroy]")
    if (!destroy) return row.remove()
    destroy.value = "1"
    row.hidden = true
    row.querySelectorAll('input:not([type="hidden"]),select,textarea').forEach((input) => { input.disabled = true })
  }
}
