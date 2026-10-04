import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors, openDashboardSelector } from "./selector_coordinator"

export default class extends Controller {
    connect() {
        this.boundOutsideClick = this.handleOutsideClick.bind(this)
        this.boundEscape = this.handleEscape.bind(this)

        document.addEventListener("click", this.boundOutsideClick)
        document.addEventListener("keydown", this.boundEscape)
    }

    disconnect() {
        document.removeEventListener("click", this.boundOutsideClick)
        document.removeEventListener("keydown", this.boundEscape)
    }

    openBranch(event) {
        const selector = event.currentTarget.closest("[data-dashboard-selector]")

        openDashboardSelector(selector)
    }

    handleOutsideClick(event) {
        if (!this.element.contains(event.target)) {
            closeDashboardSelectors()
        }
    }

    handleEscape(event) {
        if (event.key === "Escape") {
            closeDashboardSelectors()
        }
    }
}
