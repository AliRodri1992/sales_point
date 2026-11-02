import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button", "iconOpen", "iconClose", "accountMenu"]
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
    if (!open) this.closeAccountMenus()
  }

  keydown(event) {
    if (event.key !== "Escape" || event.defaultPrevented) return
    const accountMenu = this.accountMenuTargets.find((menu) => menu.open)
    if (accountMenu) {
      event.preventDefault()
      accountMenu.open = false
      accountMenu.querySelector("summary").focus()
      return
    }
    if (!this.open) return
    event.preventDefault()
    this.close()
    this.buttonTarget.focus()
  }

  outsideClick(event) {
    this.accountMenuTargets.forEach((menu) => {
      if (!menu.contains(event.target)) menu.open = false
    })
    if (this.open && !this.element.contains(event.target)) this.close()
  }

  resize() {
    this.closeAccountMenus()
    if (window.matchMedia("(min-width: 1280px)").matches) this.close()
  }

  closeAccountMenus() {
    this.accountMenuTargets.forEach((menu) => { menu.open = false })
  }
}
