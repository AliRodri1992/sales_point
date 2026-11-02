import { Controller } from "@hotwired/stimulus"

// Manual navigation leaves readers in control, including on mobile and reduced motion.
export default class extends Controller {
  static targets = ["slide", "status", "controls"]

  connect() {
    this.currentSlide = 0
    this.updatePosition()
    if (this.hasControlsTarget) {
      this.controlsTarget.classList.remove("hidden")
      this.controlsTarget.classList.add("flex")
    }
  }

  previous() {
    this.showSlide(this.currentSlide - 1)
  }

  next() {
    this.showSlide(this.currentSlide + 1)
  }

  showSlide(index) {
    if (!this.slideTargets.length) return
    this.currentSlide = (index + this.slideTargets.length) % this.slideTargets.length
    this.updatePosition()
  }

  updatePosition() {
    this.slideTargets.forEach((slide, index) => {
      slide.classList.toggle("hidden", index !== this.currentSlide)
    })
    if (this.hasStatusTarget) this.statusTarget.textContent = `${this.currentSlide + 1} / ${this.slideTargets.length}`
  }
}
