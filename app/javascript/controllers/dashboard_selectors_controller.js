import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors } from "./selector_coordinator"

export default class extends Controller {
    connect() {
        this.boundSelectorOpen = this.handleSelectorOpen.bind(this)
        this.boundOutsideClick = this.handleOutsideClick.bind(this)
        this.boundEscape = this.handleEscape.bind(this)

        this.element.addEventListener("dashboard:selector:open", this.boundSelectorOpen)
        document.addEventListener("click", this.boundOutsideClick)
        document.addEventListener("keydown", this.boundEscape)
    }

    disconnect() {
        this.element.removeEventListener("dashboard:selector:open", this.boundSelectorOpen)
        document.removeEventListener("click", this.boundOutsideClick)
        document.removeEventListener("keydown", this.boundEscape)
    }

    handleSelectorOpen(event) {
        const source = event.detail?.source

        if (source instanceof Element) {
            closeDashboardSelectors(source)
        } else {
            closeDashboardSelectors()
        }
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
