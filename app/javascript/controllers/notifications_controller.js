import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors } from "./selector_coordinator"

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

        const wasOpen = !this.menuTarget.classList.contains("hidden")

        if (wasOpen) {
            this.close()
            return
        }

        closeDashboardSelectors(this.element)
        this.open()
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
            closeDashboardSelectors()
        }
    }
}
