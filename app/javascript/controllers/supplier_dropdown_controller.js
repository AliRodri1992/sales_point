import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "label", "value"]

  connect() {
    this.onOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.onEscape = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this.onOutsideClick)
    document.addEventListener("keydown", this.onEscape)
    if (this.element.dataset.supplierFloatingMenu === "true") {
      this.onFloatingScroll = () => this.positionFloatingMenu()
      this.onToggle = () => {
        if (this.element.open) {
          this.positionFloatingMenu()
          document.addEventListener("scroll", this.onFloatingScroll, true)
          window.addEventListener("resize", this.onFloatingScroll)
        } else {
          document.removeEventListener("scroll", this.onFloatingScroll, true)
          window.removeEventListener("resize", this.onFloatingScroll)
        }
      }
      this.element.addEventListener("toggle", this.onToggle)
      if (this.element.open) this.onToggle()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.onOutsideClick)
    document.removeEventListener("keydown", this.onEscape)
    if (this.onToggle) this.element.removeEventListener("toggle", this.onToggle)
    if (this.onFloatingScroll) {
      document.removeEventListener("scroll", this.onFloatingScroll, true)
      window.removeEventListener("resize", this.onFloatingScroll)
    }
  }

  positionFloatingMenu() {
    const menu = this.element.querySelector("[data-supplier-floating-panel]")
    const trigger = this.element.querySelector("summary")
    if (!this.element.open || !menu || !trigger) return

    // Escape scrolling/overflow table ancestors using viewport positioning.
    const rect = trigger.getBoundingClientRect()
    const width = Math.max(176, menu.offsetWidth)
    const height = menu.offsetHeight
    const left = Math.max(8, Math.min(rect.right - width, window.innerWidth - width - 8))
    const showAbove = rect.bottom + height + 8 > window.innerHeight && rect.top > height + 8
    const top = showAbove ? rect.top - height - 6 : rect.bottom + 6
    Object.assign(menu.style, {
      position: "fixed",
      left: `${left}px`,
      right: "auto",
      top: `${Math.max(8, top)}px`,
      width: `${width}px`,
      zIndex: "100"
    })
  }

  choose(event) {
    const option = event.currentTarget
    if (this.hasValueTarget && option.matches("button[data-option-value]")) {
      this.valueTarget.value = option.dataset.optionValue
      this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
      this.labelTarget.textContent = option.querySelector("[data-option-label]").textContent.trim()
      this.element.querySelectorAll("button[data-option-value]").forEach((button) => {
        button.setAttribute("aria-selected", String(button === option))
      })
      this.close(true)
      return
    }

    const input = option.closest("label")?.querySelector("input")
    if (!input) return

    event.preventDefault()
    input.checked = true
    input.dispatchEvent(new Event("change", { bubbles: true }))
    this.labelTarget.textContent = option.querySelector("[data-option-label]").textContent.trim()
    this.close()
  }

  navigate(event) {
    if (!this.hasValueTarget || !["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return

    const options = Array.from(this.element.querySelectorAll("button[data-option-value]"))
    if (options.length === 0) return

    const current = options.indexOf(document.activeElement)
    let index = current
    if (event.key === "ArrowDown") index = (current + 1) % options.length
    if (event.key === "ArrowUp") index = (current - 1 + options.length) % options.length
    if (event.key === "Home") index = 0
    if (event.key === "End") index = options.length - 1

    event.preventDefault()
    options[index].focus()
  }

  close(refocus = false) {
    this.element.open = false
    if (this.onFloatingScroll) {
      document.removeEventListener("scroll", this.onFloatingScroll, true)
      window.removeEventListener("resize", this.onFloatingScroll)
    }
    if (refocus) this.element.querySelector("summary")?.focus()
  }
}
