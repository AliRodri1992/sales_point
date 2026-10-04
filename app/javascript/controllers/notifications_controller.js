import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["button", "menu"]

    toggle(event) {
        event.preventDefault()

        const shouldOpen = this.menuTarget.classList.contains("hidden")

        if (shouldOpen) {
            this.dispatch("open", {
                detail: { source: this.element },
                bubbles: true
            })
            this.open()
            return
        }

        this.close()
    }

    open() {
        this.menuTarget.classList.remove("hidden")
        this.buttonTarget.setAttribute("aria-expanded", "true")
    }

    close() {
        this.menuTarget.classList.add("hidden")
        this.buttonTarget.setAttribute("aria-expanded", "false")
    }
}
