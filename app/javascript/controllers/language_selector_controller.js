import { Controller } from "@hotwired/stimulus"
import { openDashboardSelector, closeDashboardSelectors } from "./selector_coordinator"

export default class extends Controller {
    static targets = ["dropdown"]

    toggle(event) {
        event.preventDefault()

        const willOpen = this.dropdownTarget.classList.contains("hidden")

        if (!willOpen) {
            this.close()
            return
        }

        openDashboardSelector(this.element)
        this.dropdownTarget.classList.remove("hidden")
        this.refreshDropdownContent()
    }

    close() {
        this.dropdownTarget.classList.add("hidden")
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
        const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

        fetch("/language", {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": csrfToken
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
