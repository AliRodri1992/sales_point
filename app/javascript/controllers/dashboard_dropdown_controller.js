import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors, isDashboardSelectorOpen } from "./selector_coordinator"

export default class extends Controller {
    connect() {
        this.boundClick = this.handleClick.bind(this)
        this.boundOutsideClick = this.handleOutsideClick.bind(this)
        this.boundEscape = this.handleEscape.bind(this)

        this.element.addEventListener("click", this.boundClick)
        document.addEventListener("click", this.boundOutsideClick)
        document.addEventListener("keydown", this.boundEscape)
    }

    disconnect() {
        this.element.removeEventListener("click", this.boundClick)
        document.removeEventListener("click", this.boundOutsideClick)
        document.removeEventListener("keydown", this.boundEscape)
    }

    handleClick(event) {
        if (!event.target.closest("summary")) return

        requestAnimationFrame(() => {
            if (isDashboardSelectorOpen(this.element)) {
                closeDashboardSelectors(this.element)
            }
        })
    }

    handleOutsideClick(event) {
        if (this.element.contains(event.target)) return

        closeDashboardSelectors()
    }

    handleEscape(event) {
        if (event.key !== "Escape") return

        closeDashboardSelectors()
    }
}
