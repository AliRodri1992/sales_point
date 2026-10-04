import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["dropdown"]

    connect() {
        this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
        this.boundCloseOnEscape = this.closeOnEscape.bind(this)
        this.boundCloseOtherSelector = this.closeOtherSelector.bind(this)

        document.addEventListener("click", this.boundCloseOnClickOutside)
        document.addEventListener("keydown", this.boundCloseOnEscape)
        document.addEventListener("dashboard:selector-opened", this.boundCloseOtherSelector)
    }

    disconnect() {
        document.removeEventListener("click", this.boundCloseOnClickOutside)
        document.removeEventListener("keydown", this.boundCloseOnEscape)
        document.removeEventListener("dashboard:selector-opened", this.boundCloseOtherSelector)
    }

    toggle(event) {
        event.stopPropagation()

        const willOpen = this.dropdownTarget.classList.contains("hidden")

        if (willOpen) {
            this.open()
        } else {
            this.close()
        }
    }

    open() {
        this.closeOtherSelector()

        this.dropdownTarget.classList.remove("hidden")
        document.dispatchEvent(new CustomEvent("dashboard:selector-opened", {
            detail: { source: this.element }
        }))
        this.refreshDropdownContent()
    }

    close() {
        this.dropdownTarget.classList.add("hidden")
    }

    closeOnClickOutside(event) {
        if (this.dropdownTarget.classList.contains("hidden")) return
        if (this.element.contains(event.target)) return

        this.close()
    }

    closeOnEscape(event) {
        if (event.key !== "Escape") return

        this.close()
    }

    closeOtherSelector(event) {
        if (event?.detail?.source === this.element) return

        const details = this.element.querySelector("details")

        if (details?.open) {
            details.open = false
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

            if (response.ok) {
                const html = await response.text()
                const parser = new DOMParser()
                const doc = parser.parseFromString(html, "text/html")
                const newContent = doc.getElementById("language_selector_content")
                const currentContent = document.getElementById("language_selector_content")

                if (newContent && currentContent) {
                    currentContent.innerHTML = newContent.innerHTML
                }
            }
        } catch (error) {
            console.error("Error refreshing language dropdown:", error)
        }
    }

    select(event) {
        event.stopPropagation()

        const button = event.currentTarget
        const language = button.dataset.language

        fetch("/language", {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
            },
            body: JSON.stringify({ language: language })
        })
            .then(() => {
                this.close()
                window.location.reload()
            })
            .catch((error) => {
                console.error("Language change error:", error)
            })
    }
}
