import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "template", "empty"]

  connect() {
    this.updateEmptyState()
  }

  updateEmptyState() {
    if (!this.hasEmptyTarget) return
    const visible = [...this.itemsTarget.querySelectorAll("[data-phone-item]")]
      .some((item) => !item.hidden && item.querySelector('input[name$="[_destroy]"]')?.value !== "1")
    this.emptyTarget.classList.toggle("hidden", visible)
  }

  add(event) {
    event?.preventDefault()
    if (!this.hasItemsTarget || !this.hasTemplateTarget) return

    const id = `${Date.now()}${Math.floor(Math.random() * 100000).toString().padStart(5, "0")}`
    const markup = this.templateTarget.innerHTML.replaceAll("NEW_PHONE", id)
    this.itemsTarget.insertAdjacentHTML("beforeend", markup)
    this.updateEmptyState()

    const phone = this.itemsTarget.querySelector("[data-phone-item]:last-child")
    phone?.querySelector('input[name$="[number]"]')?.focus()
  }

  remove(event) {
    const item = event.currentTarget.closest("[data-phone-item]")
    if (!item) return

    // Unsaved phone rows can disappear immediately; persisted records need an undo option.
    const savedId = item.querySelector('input[type="hidden"][name$="[id]"]')?.value
    if (!savedId) {
      item.remove()
      this.updateEmptyState()
      return
    }

    const destroy = item.querySelector('input[name$="[_destroy]"]')
    const fields = item.querySelector("[data-phone-fields]")
    const notice = item.querySelector("[data-phone-removed-message]")
    if (destroy && fields && notice) {
      destroy.value = "1"
      fields.classList.add("hidden")
      notice.classList.remove("hidden")
      notice.classList.add("flex")
      notice.querySelector("button")?.focus()
    } else if (destroy) {
      // Preserve the legacy behavior in forms that use the shared phone partial.
      destroy.value = "1"
      item.hidden = true
    } else {
      item.remove()
    }
    this.updateEmptyState()
  }

  undoRemove(event) {
    const item = event.currentTarget.closest("[data-phone-item]")
    if (!item) return
    const destroy = item.querySelector('input[name$="[_destroy]"]')
    const fields = item.querySelector("[data-phone-fields]")
    const notice = item.querySelector("[data-phone-removed-message]")
    if (!destroy || !fields || !notice) return

    destroy.value = "0"
    fields.classList.remove("hidden")
    notice.classList.add("hidden")
    notice.classList.remove("flex")
    fields.querySelector("input:not([type=hidden]), select")?.focus()
    const primary = item.querySelector('input[type="checkbox"][name$="[primary]"]')
    if (primary?.checked) this.primaryChanged({ target: primary })
    this.updateEmptyState()
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
