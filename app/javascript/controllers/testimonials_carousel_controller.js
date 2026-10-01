import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "previous", "next"]

  connect() {
    this.updateControls()
    this.boundUpdateControls = this.updateControls.bind(this)
    this.viewportTarget.addEventListener("scroll", this.boundUpdateControls, { passive: true })
    window.addEventListener("resize", this.boundUpdateControls)
  }

  disconnect() {
    this.viewportTarget.removeEventListener("scroll", this.boundUpdateControls)
    window.removeEventListener("resize", this.boundUpdateControls)
  }

  previous() {
    this.scrollByPage(-1)
  }

  next() {
    this.scrollByPage(1)
  }

  scrollByPage(direction) {
    this.viewportTarget.scrollBy({
      left: direction * this.viewportTarget.clientWidth,
      behavior: "smooth"
    })
  }

  updateControls() {
    const maxScrollLeft = this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth
    const atStart = this.viewportTarget.scrollLeft <= 1
    const atEnd = this.viewportTarget.scrollLeft >= maxScrollLeft - 1

    this.previousTarget.disabled = atStart
    this.nextTarget.disabled = atEnd
    this.previousTarget.setAttribute("aria-disabled", atStart)
    this.nextTarget.setAttribute("aria-disabled", atEnd)
  }
}
