import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "form", "method", "heading", "submit"]

  connect() {
    this.handleKeydown = (event) => {
      if (event.key === "Escape" && this.hasDrawerTarget && !this.drawerTarget.classList.contains("hidden")) {
        this.close()
      }
    }
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.body.style.overflow = ""
  }

  open() {
    this.formTarget.reset()
    this.formTarget.action = this.formTarget.dataset.createUrl || this.formTarget.action
    this.methodTarget.value = ""
    this.headingTarget.textContent = this.headingTarget.dataset.newText
    this.submitTarget.value = this.submitTarget.dataset.newText
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
    this.drawerTarget.classList.remove("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "false")
    document.body.style.overflow = "hidden"
    this.drawerTarget.querySelector("input[name='supplier_event[title]']")?.focus()
  }

  close() {
    this.drawerTarget.classList.add("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "true")
    document.body.style.overflow = ""
  }
}
