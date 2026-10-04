import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["button", "menu"]

    connect() {
        this.boundEscape = this.closeOnEscape.bind(this)
        document.addEventListener("keydown", this.boundEscape)
    }

    disconnect() {
        document.removeEventListener("keydown", this.boundEscape)
    }

    toggle(event) {
        event.preventDefault()
        event.stopPropagation()

        const shouldOpen = this.menuTarget.classList.contains("hidden")

        if (shouldOpen) {
            document.dispatchEvent(new CustomEvent("dashboard:selector:open", {
                detail: { source: this.element }
            }))
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

    closeOnEscape(event) {
        if (event.key === "Escape") {
            this.close()
        }
    }
}
