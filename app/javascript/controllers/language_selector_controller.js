import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors } from "./selector_coordinator"

export default class extends Controller {
    static targets = ["dropdown"]

    connect() {
        this.boundOutsideClick = this.closeOnClickOutside.bind(this)
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

        const willOpen = this.dropdownTarget.classList.contains("hidden")

        if (!willOpen) {
            this.close()
            return
        }

        document.dispatchEvent(new CustomEvent("dashboard:selector:open", {
            detail: { source: this.element }
        }))
        this.dropdownTarget.classList.remove("hidden")
        this.refreshDropdownContent()
    }

    close() {
        this.dropdownTarget.classList.add("hidden")
    }

    closeOnClickOutside(event) {
        if (!this.element.contains(event.target)) {
            closeDashboardSelectors()
        }
    }

    closeOnEscape(event) {
        if (event.key === "Escape") {
            closeDashboardSelectors()
        }
    }

    async refreshDropdownContent() {
        try {
            const response = await fetch("/admin/languages/content", {
                method: "GET",
                headers: {
                    "Accept": "text/html"
                }
            })

            if (!response.ok) return

            const html = await response.text()
            const parser = new DOMParser()
            const newContent = parser.parseFromString(html, "text/html")
                .getElementById("language_selector_content")
            const currentContent = document.getElementById("language_selector_content")

            if (newContent && currentContent) {
                currentContent.innerHTML = newContent.innerHTML
            }
        } catch (error) {
            console.error("Error refreshing language dropdown:", error)
        }
    }

    select(event) {
        event.stopPropagation()

        const language = event.currentTarget.dataset.language

        fetch("/language", {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
            },
            body: JSON.stringify({ language })
        })
            .then(() => {
                closeDashboardSelectors()
                window.location.reload()
            })
            .catch((error) => {
                console.error("Language change error:", error)
            })
    }
}
