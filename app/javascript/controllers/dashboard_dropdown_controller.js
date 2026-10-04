import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
        this.boundCloseOnEscape = this.closeOnEscape.bind(this)
        this.boundCloseOnSelectorOpened = this.closeOnSelectorOpened.bind(this)
        this.boundToggleSelector = this.toggleSelector.bind(this)

        this.element.addEventListener("click", this.boundToggleSelector)
        document.addEventListener("click", this.boundCloseOnClickOutside)
        document.addEventListener("keydown", this.boundCloseOnEscape)
        document.addEventListener("dashboard:selector-opened", this.boundCloseOnSelectorOpened)
    }

    disconnect() {
        this.element.removeEventListener("click", this.boundToggleSelector)
        document.removeEventListener("click", this.boundCloseOnClickOutside)
        document.removeEventListener("keydown", this.boundCloseOnEscape)
        document.removeEventListener("dashboard:selector-opened", this.boundCloseOnSelectorOpened)
    }

    toggleSelector(event) {
        if (!event.target.closest("summary")) return

        requestAnimationFrame(() => {
            const details = this.element.querySelector("details")

            if (details?.open) {
                document.dispatchEvent(new CustomEvent("dashboard:selector-opened", {
                    detail: { source: this.element }
                }))
            }
        })
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
