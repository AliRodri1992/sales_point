import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "button"]

    connect() {
        this.update()
    }

    update() {
        const empty = this.inputTarget.value.trim().length === 0
        this.buttonTarget.disabled = empty
        this.buttonTarget.classList.toggle("opacity-50", empty)
        this.buttonTarget.classList.toggle("cursor-not-allowed", empty)
    }
}