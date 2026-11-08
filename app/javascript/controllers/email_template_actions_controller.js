import { Controller } from "@hotwired/stimulus"

// Portal the row menu above the scrollable table, preserving keyboard access.
export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.menu = this.panelTarget
    this.onOutside = (event) => {
      if (!this.element.contains(event.target) && !this.menu.contains(event.target)) this.close()
    }
    this.onKeydown = (event) => {
      if (event.key !== "Escape") return
      this.close()
      this.buttonTarget.focus()
    }
    this.onReposition = () => this.position()
  }

  disconnect() {
    this.removeListeners()
    if (this.menu?.parentElement === document.body) this.menu.remove()
  }

  toggle() {
    if (this.menu.hidden) this.open()
    else this.close()
  }

  open() {
    this.menu.hidden = false
    document.body.appendChild(this.menu)
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.position()
    document.addEventListener("pointerdown", this.onOutside)
    document.addEventListener("keydown", this.onKeydown)
    window.addEventListener("resize", this.onReposition)
    window.addEventListener("scroll", this.onReposition, true)
  }

  close() {
    if (!this.menu || this.menu.hidden) return
    this.menu.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.removeListeners()
    if (this.element.isConnected) this.element.appendChild(this.menu)
  }

  removeListeners() {
    document.removeEventListener("pointerdown", this.onOutside)
    document.removeEventListener("keydown", this.onKeydown)
    window.removeEventListener("resize", this.onReposition)
    window.removeEventListener("scroll", this.onReposition, true)
  }

  position() {
    if (this.menu.hidden || !this.element.isConnected) return
    const anchor = this.buttonTarget.getBoundingClientRect()
    const width = this.menu.offsetWidth
    const spaceBelow = window.innerHeight - anchor.bottom
    const upwards = spaceBelow < 260 && anchor.top > spaceBelow
    this.menu.style.left = `${Math.max(8, Math.min(anchor.right - width, window.innerWidth - width - 8))}px`
    this.menu.style.maxHeight = `${Math.max(120, (upwards ? anchor.top : spaceBelow) - 12)}px`
    this.menu.style.top = upwards ? "auto" : `${anchor.bottom + 6}px`
    this.menu.style.bottom = upwards ? `${window.innerHeight - anchor.top + 6}px` : "auto"
  }
}
