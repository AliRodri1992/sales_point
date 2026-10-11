import { Controller } from "@hotwired/stimulus"

// Repeatable nested attributes; keep persisted rows for Rails _destroy.
export default class extends Controller {
  static targets = ["items", "template"]

  add() {
    const key = `new_${Date.now()}_${Math.floor(Math.random() * 100000)}`
    const fragment = this.templateTarget.content.cloneNode(true)
    fragment.querySelectorAll("[name], [id], [for]").forEach((node) => {
      for (const attribute of ["name", "id", "for"]) {
        if (node.hasAttribute(attribute)) {
          node.setAttribute(attribute, node.getAttribute(attribute).replaceAll("NEW_RECORD", key))
        }
      }
    })
    this.itemsTarget.append(fragment)
  }

  remove(event) {
    const item = event.currentTarget.closest("[data-supplier-nested-item]")
    if (!item) return

    const destroy = item.querySelector("[data-supplier-nested-destroy]")
    const id = item.querySelector('input[name$="[id]"]')
    if (id && id.value) {
      destroy.value = "1"
      item.hidden = true
      item.querySelectorAll("input, select, textarea").forEach((field) => {
        if (field !== destroy && field !== id) field.disabled = true
      })
    } else {
      item.remove()
    }
  }
}
