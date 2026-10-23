import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "form", "method", "heading", "submit"]

  connect() {
    this.handleKeydown = (event) => this.onKeydown(event)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    if (this.hasDrawerTarget && !this.drawerTarget.classList.contains("hidden")) {
      document.body.style.overflow = this.previousOverflow || ""
    }
  }

  open(event) {
    this.formTarget.reset()
    this.formTarget.action = this.formTarget.dataset.createUrl
    this.methodTarget.value = ""
    this.headingTarget.textContent = this.headingTarget.dataset.newText
    this.submitTarget.value = this.submitTarget.dataset.newText
    const date = event?.currentTarget?.dataset.date
    if (date && /^\d{4}-\d{2}-\d{2}$/.test(date)) {
      this.fill("starts_at", `${date}T09:00`)
      this.fill("ends_at", `${date}T10:00`)
    }
    this.showDrawer()
  }

  edit(event) {
    event.preventDefault()
    const values = event.currentTarget.dataset
    this.formTarget.reset()
    this.formTarget.action = values.eventUrl
    this.methodTarget.value = "patch"
    this.fill("title", values.eventTitle)
    this.fill("kind", values.eventKind)
    this.fill("branch_id", values.eventBranch)
    this.fill("starts_at", values.eventStart)
    this.fill("ends_at", values.eventEnd)
    this.fill("notes", values.eventNotes)
    this.headingTarget.textContent = this.headingTarget.dataset.editText
    this.submitTarget.value = this.submitTarget.dataset.editText
    this.showDrawer()
  }

  fill(field, value) {
    const input = this.formTarget.elements.namedItem(`supplier_event[${field}]`)
    if (input) input.value = value || ""
  }

  showDrawer() {
    this.previousFocus = document.activeElement
    this.previousOverflow = document.body.style.overflow
    this.drawerTarget.classList.remove("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "false")
    document.body.style.overflow = "hidden"
    this.drawerTarget.querySelector("input[name='supplier_event[title]']")?.focus()
  }

  close() {
    if (this.drawerTarget.classList.contains("hidden")) return

    this.drawerTarget.classList.add("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "true")
    document.body.style.overflow = this.previousOverflow || ""
    this.previousFocus?.focus()
  }

  onKeydown(event) {
    if (!this.hasDrawerTarget || this.drawerTarget.classList.contains("hidden")) return
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  trapFocus(event) {
    const selector = 'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])'
    const dialog = this.drawerTarget.querySelector('[role="dialog"]')
    const inputs = [...dialog.querySelectorAll(selector)].filter((node) => node.getClientRects().length)
    if (inputs.length === 0) return

    const first = inputs[0]
    const last = inputs[inputs.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }
}
