import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "label", "value"]

  connect() {
    this.floatingPanel = this.element.dataset.supplierFloatingMenu === "true"
      ? this.element.querySelector("[data-supplier-floating-panel]")
      : null
    this.trigger = this.floatingPanel ? this.element.querySelector("summary") : null

    this.onOutsideClick = (event) => {
      if (this.element.contains(event.target) || this.floatingPanel?.contains(event.target)) return

      this.close()
    }
    this.onEscape = (event) => {
      if (event.key === "Escape" && this.element.open) this.close(true)
    }
    document.addEventListener("click", this.onOutsideClick)
    document.addEventListener("keydown", this.onEscape)

    this.onValueChange = () => this.sync()
    if (this.hasValueTarget) {
      this.valueTarget.addEventListener("change", this.onValueChange)
      this.sync()
    }

    if (this.floatingPanel) {
      this.trigger?.setAttribute("aria-expanded", String(this.element.open))
      this.onFloatingScroll = () => this.positionFloatingMenu()
      this.onBeforeCache = () => this.close()
      this.onToggle = () => {
        this.trigger?.setAttribute("aria-expanded", String(this.element.open))
        if (this.element.open) {
          this.mountFloatingMenu()
          this.positionFloatingMenu()
          document.addEventListener("scroll", this.onFloatingScroll, true)
          window.addEventListener("resize", this.onFloatingScroll)
        } else {
          this.stopFloatingTracking()
          this.restoreFloatingMenu()
        }
      }
      this.element.addEventListener("toggle", this.onToggle)
      document.addEventListener("turbo:before-cache", this.onBeforeCache)
      if (this.element.open) this.onToggle()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.onOutsideClick)
    document.removeEventListener("keydown", this.onEscape)
    if (this.hasValueTarget) this.valueTarget.removeEventListener("change", this.onValueChange)
    if (this.onToggle) this.element.removeEventListener("toggle", this.onToggle)
    if (this.onBeforeCache) document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.stopFloatingTracking()
    this.restoreFloatingMenu()
  }

  mountFloatingMenu() {
    if (this.floatingPanel?.parentElement !== document.body) {
      document.body.appendChild(this.floatingPanel)
    }
  }

  restoreFloatingMenu() {
    const menu = this.floatingPanel
    if (!menu || menu.parentElement === this.element) return

    for (const property of ["position", "left", "right", "top", "width",
                             "max-width", "max-height", "overflow-y", "margin-top", "z-index"]) {
      menu.style.removeProperty(property)
    }
    this.element.appendChild(menu)
  }

  stopFloatingTracking() {
    if (!this.onFloatingScroll) return

    document.removeEventListener("scroll", this.onFloatingScroll, true)
    window.removeEventListener("resize", this.onFloatingScroll)
  }

  positionFloatingMenu() {
    const menu = this.floatingPanel
    const trigger = this.trigger
    if (!this.element.open || !menu || !trigger) return

    // Fixed positioning alone cannot escape overflow-x-auto: portal into body.
    const rect = trigger.getBoundingClientRect()
    const margin = 8
    const gap = 6
    const width = Math.min(Math.max(176, menu.offsetWidth), window.innerWidth - margin * 2)
    const height = menu.scrollHeight
    const below = window.innerHeight - rect.bottom - gap - margin
    const above = rect.top - gap - margin
    const showAbove = height > below && above > below
    const available = Math.max(0, showAbove ? above : below)
    const visibleHeight = Math.min(height, available)
    const top = showAbove ? rect.top - gap - visibleHeight : rect.bottom + gap
    const left = Math.min(
      Math.max(margin, rect.right - width),
      window.innerWidth - margin - width
    )

    Object.assign(menu.style, {
      position: "fixed",
      left: `${left}px`,
      right: "auto",
      top: `${Math.max(margin, top)}px`,
      width: `${width}px`,
      maxWidth: `calc(100vw - ${margin * 2}px)`,
      maxHeight: `${visibleHeight}px`,
      overflowY: "auto",
      marginTop: "0",
      zIndex: "1000"
    })
  }

  choose(event) {
    const option = event.currentTarget
    if (!this.hasValueTarget || !option.matches("button[data-option-value]")) return

    this.valueTarget.value = option.dataset.optionValue
    this.sync()
    this.close(true)
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  sync() {
    if (!this.hasValueTarget || !this.hasLabelTarget) return
    const options = Array.from(this.element.querySelectorAll("button[data-option-value]"))
    const selected = options.find((option) => option.dataset.optionValue === this.valueTarget.value) || options[0]
    if (!selected) return

    this.labelTarget.textContent = selected.querySelector("[data-option-label]")?.textContent.trim() || ""
    options.forEach((option) => option.setAttribute("aria-selected", String(option === selected)))
  }

  reset() {
    if (!this.hasValueTarget) return
    this.valueTarget.value = this.element.dataset.supplierDropdownDefaultValue ?? ""
    this.sync()
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
    this.trigger?.setAttribute("aria-expanded", "false")
    this.stopFloatingTracking()
    this.restoreFloatingMenu()
    if (refocus) this.element.querySelector("summary")?.focus()
  }
}
