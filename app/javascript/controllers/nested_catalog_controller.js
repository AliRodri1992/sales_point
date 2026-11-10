import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.refreshLinks()
  }

  add(event) {
    const group = event.currentTarget.closest("[data-nested-catalog-group]")
    const rows = group.querySelector("[data-nested-catalog-rows]")
    if (rows.children.length >= Number(group.dataset.nestedCatalogLimit || 50)) return
    const template = group.querySelector("template").innerHTML
    rows.insertAdjacentHTML("beforeend", template.replaceAll("NEW_RECORD", String(this.sequence = (this.sequence || Date.now()) + 1)))
    this.refreshLinks()
    rows.lastElementChild.querySelector("input:not([type=hidden]),select")?.focus()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-nested-catalog-row]")
    const destroy = row.querySelector("[data-nested-catalog-destroy]")
    if (!destroy) row.remove()
    else {
      destroy.value = "1"
      row.hidden = true
      row.querySelectorAll('input:not([type="hidden"]),select,textarea').forEach((input) => { input.disabled = true })
    }
    this.refreshLinks()
  }

  refreshLinks() {
    const kinds = { variants: "product_variant_id", presentations: "product_presentation_id" }
    for (const [kind, target] of Object.entries(kinds)) {
      const rows = [...this.element.querySelectorAll(`[data-nested-catalog-kind="${kind}"]`)]
      const pending = rows.filter((row) => !row.hidden).map((row) => ({
        key: row.querySelector('input[name$="[client_key]"]')?.value,
        name: row.querySelector('input[name$="[name]"]')?.value?.trim()
      })).filter((item) => item.key && item.name)

      const selectors = this.element.querySelectorAll(`[data-nested-catalog-kind="barcodes"] select[name$="[${target}]"]`)
      for (const select of selectors) {
        // Keep existing options mounted: removing a selected <option> during
        // another input event resets native select values in real browsers.
        const available = new Map(pending.map((item) => [`new:${item.key}`, item.name]))
        select.querySelectorAll("option[data-nested-catalog-generated]").forEach((option) => {
          if (!available.has(option.value)) {
            option.remove()
            return
          }
          const name = available.get(option.value)
          if (option.textContent !== name) option.textContent = name
          available.delete(option.value)
        })
        available.forEach((name, value) => {
          const option = document.createElement("option")
          option.value = value
          option.textContent = name
          option.dataset.nestedCatalogGenerated = "true"
          select.add(option)
        })
        const restore = select.closest("[data-nested-catalog-pending-value]")?.dataset.nestedCatalogPendingValue
        const savedValue = restore && `new:${restore}`
        if (!select.value && savedValue && [...select.options].some((option) => option.value === savedValue)) {
          select.value = savedValue
        }
      }
    }
  }
}
