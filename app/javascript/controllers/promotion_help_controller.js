import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "panel"]

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.position()
    this.reposition = () => this.position()
    window.addEventListener("resize", this.reposition)
    document.addEventListener("scroll", this.reposition, true)
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    window.removeEventListener("resize", this.reposition)
    document.removeEventListener("scroll", this.reposition, true)
  }

  disconnect() {
    window.removeEventListener("resize", this.reposition)
    document.removeEventListener("scroll", this.reposition, true)
  }

  position() {
    const anchor = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const width = Math.min(336, window.innerWidth - 16)
    const height = panel.scrollHeight
    const top = window.innerHeight - anchor.bottom < height && anchor.top > window.innerHeight - anchor.bottom
      ? Math.max(8, anchor.top - height - 8) : anchor.bottom + 8
    Object.assign(panel.style, { width: `${width}px`, left: `${Math.max(8, Math.min(anchor.right - width, window.innerWidth - width - 8))}px`, top: `${top}px`, maxHeight: `${Math.max(100, window.innerHeight - top - 8)}px` })
  }

  outside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  escape(event) {
    if (this.panelTarget.hidden) return
    event.preventDefault()
    this.closeAndFocus()
  }

  closeAndFocus() {
    this.close()
    this.triggerTarget.focus()
  }
}
