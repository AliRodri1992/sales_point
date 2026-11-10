import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.composing = false
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  compositionStart() {
    this.composing = true
  }

  compositionEnd() {
    this.composing = false
    this.schedule()
  }

  schedule() {
    if (this.composing) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 350)
  }

  change() {
    clearTimeout(this.timer)
    this.element.requestSubmit()
  }
}
