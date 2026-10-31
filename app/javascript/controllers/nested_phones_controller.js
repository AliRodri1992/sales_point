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
}
