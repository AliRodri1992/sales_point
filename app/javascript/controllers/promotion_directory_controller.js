import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  sort() {
    this.element.requestSubmit()
  }
}
