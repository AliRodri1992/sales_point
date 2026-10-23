import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer"]

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
