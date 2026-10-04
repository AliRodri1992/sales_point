import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
        this.boundCloseOnEscape = this.closeOnEscape.bind(this)
        this.boundCloseOnSelectorOpened = this.closeOnSelectorOpened.bind(this)

        document.addEventListener("click", this.boundCloseOnClickOutside)
        document.addEventListener("keydown", this.boundCloseOnEscape)
        document.addEventListener("dashboard:selector-opened", this.boundCloseOnSelectorOpened)
    }

    disconnect() {
        document.removeEventListener("click", this.boundCloseOnClickOutside)
        document.removeEventListener("keydown", this.boundCloseOnEscape)
        document.removeEventListener("dashboard:selector-opened", this.boundCloseOnSelectorOpened)
    }

    closeOnClickOutside(event) {
        if (!this.element.querySelector("details")?.open) return
        if (this.element.contains(event.target)) return

        this.element.querySelector("details").open = false
    }

    closeOnEscape(event) {
        if (event.key !== "Escape") return

        const details = this.element.querySelector("details")

        if (details?.open) {
            details.open = false
        }
    }

    closeOnSelectorOpened(event) {
        if (event.detail?.source === this.element) return

        const details = this.element.querySelector("details")

        if (details?.open) {
            details.open = false
        }
    }
}
