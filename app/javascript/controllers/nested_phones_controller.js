import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "template"]

  add() {
    const id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`
    this.itemsTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("NEW_PHONE", id))
  }

  remove(event) {
    const item = event.target.closest("[data-phone-item]")
    if (!item) return

    const destroy = item.querySelector('input[name$="[_destroy]"]')
    if (destroy) {
      destroy.value = "1"
      item.hidden = true
    } else {
      item.remove()
    }
  }
  primaryChanged(event) {
    if (!event.target.checked) return

    const selected = event.target.closest("[data-phone-item]")
    const kind = selected?.querySelector('select[name$="[kind]"]')?.value
    if (!kind) return

    this.itemsTarget.querySelectorAll("[data-phone-item]").forEach((item) => {
      if (item === selected || item.hidden) return
      if (item.querySelector('select[name$="[kind]"]')?.value !== kind) return

      const checkbox = item.querySelector('input[type="checkbox"][name$="[primary]"]')
      if (checkbox) checkbox.checked = false
    })
  }

  kindChanged(event) {
    const item = event.target.closest("[data-phone-item]")
    const checkbox = item?.querySelector('input[type="checkbox"][name$="[primary]"]')
    if (checkbox?.checked) this.primaryChanged({ target: checkbox })
  }

}
