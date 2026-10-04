import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors } from "./selector_coordinator"

export default class extends Controller {
    connect() {
        this.boundOutsideClick = this.closeOnOutsideClick.bind(this)
        this.boundEscape = this.closeOnEscape.bind(this)

        document.addEventListener("click", this.boundOutsideClick)
        document.addEventListener("keydown", this.boundEscape)
    }

    disconnect() {
        document.removeEventListener("click", this.boundOutsideClick)
        document.removeEventListener("keydown", this.boundEscape)
    }

    toggle(event) {
        event.preventDefault()
        event.stopPropagation()

        const willOpen = this.menu?.classList.contains("hidden")

        if (!willOpen) {
            this.close()
            return
        }

        closeDashboardSelectors(this.element)
        this.menu?.classList.remove("hidden")
        this.button?.setAttribute("aria-expanded", "true")
    }

    get button() {
        return this.element.querySelector("#notificationsButton")
    }

    get menu() {
        return this.element.querySelector("#notificationsMenu")
    }

    close() {
        this.menu?.classList.add("hidden")
        this.button?.setAttribute("aria-expanded", "false")
    }

    closeOnOutsideClick(event) {
        if (this.element.contains(event.target)) return

        closeDashboardSelectors()
    }

    closeOnEscape(event) {
        if (event.key === "Escape") {
            closeDashboardSelectors()
        }
    }
}
