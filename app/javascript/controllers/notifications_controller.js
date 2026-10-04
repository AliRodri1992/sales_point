import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors } from "./selector_coordinator"

export default class extends Controller {
    connect() {
        this.button = this.element.querySelector("#notificationsButton")
        this.menu = this.element.querySelector("#notificationsMenu")
        this.boundToggle = this.toggle.bind(this)
        this.boundOutsideClick = this.closeOnOutsideClick.bind(this)
        this.boundEscape = this.closeOnEscape.bind(this)

        this.button?.addEventListener("click", this.boundToggle)
        document.addEventListener("click", this.boundOutsideClick)
        document.addEventListener("keydown", this.boundEscape)
    }

    disconnect() {
        this.button?.removeEventListener("click", this.boundToggle)
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
