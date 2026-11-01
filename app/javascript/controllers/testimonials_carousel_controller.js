import { Controller } from "@hotwired/stimulus"

const AUTOPLAY_INTERVAL = 5000

export default class extends Controller {
  static targets = ["track"]

  connect() {
    this.currentSlide = 0
    this.totalSlides = this.trackTarget.children.length
    this.startAutoplay()
  }

  disconnect() {
    this.stopAutoplay()
  }

  startAutoplay() {
    this.stopAutoplay()

    if (this.totalSlides <= 1) return

    this.interval = window.setInterval(() => {
      this.next()
    }, AUTOPLAY_INTERVAL)
  }

  stopAutoplay() {
    if (this.interval) {
      window.clearInterval(this.interval)
      this.interval = null
    }
  }

  next() {
    this.currentSlide = (this.currentSlide + 1) % this.totalSlides
    this.updatePosition()
  }

  updatePosition() {
    this.trackTarget.style.transform = `translateX(-${this.currentSlide * 100}%)`
  }
}
