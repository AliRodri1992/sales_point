import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button", "iconOpen", "iconClose"]
  static values = { openLabel: String, closeLabel: String }

  connect() {
    this.close()
  }

  toggle() {
    this.setOpen(!this.open)
  }

  close() {
    this.setOpen(false)
  }

  setOpen(open) {
    this.open = open
    this.menuTarget.classList.toggle("hidden", !open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? this.closeLabelValue : this.openLabelValue)
    this.iconOpenTarget.classList.toggle("hidden", open)
    this.iconCloseTarget.classList.toggle("hidden", !open)
  }

  keydown(event) {
    if (event.key !== "Escape" || event.defaultPrevented || !this.open) return
    event.preventDefault()
    this.close()
    this.buttonTarget.focus()
  }

  outsideClick(event) {
    if (this.open && !this.element.contains(event.target)) this.close()
  }

  resize() {
    if (window.matchMedia("(min-width: 1280px)").matches) this.close()
  }
}
