import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["dropdown", "flag", "languageCode"]

    connect(){
        this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
        this.boundCloseOnEscape = this.closeOnEscape.bind(this)

        document.addEventListener("click", this.boundCloseOnClickOutside)
        document.addEventListener("keydown", this.boundCloseOnEscape)
    }

    disconnect(){
        document.removeEventListener("click", this.boundCloseOnClickOutside)
        document.removeEventListener("keydown", this.boundCloseOnEscape)
    }

    toggle(event){
        event.stopPropagation()
        const dropdown = this.dropdownTarget

        // Show dropdown and refresh content
        dropdown.classList.remove("hidden")
        this.refreshDropdownContent()
    }

    async refreshDropdownContent(){
        try {
            // Fetch the updated dropdown content from the server
            const response = await fetch("/admin/languages/content", {
                method: "GET",
                headers: {
                    "Accept": "text/html"
                }
            })

            if (response.ok) {
                const html = await response.text()

                // Parse the response and extract dropdown content
                const parser = new DOMParser()
                const doc = parser.parseFromString(html, "text/html")

                // Find the dropdown content element
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

    closeOnClickOutside(event){
        if (this.dropdownTarget.classList.contains("hidden")) return
        if (this.element.contains(event.target)) return

        this.dropdownTarget.classList.add("hidden")
    }

    closeOnEscape(event){
        if (event.key !== "Escape") return

        this.dropdownTarget.classList.add("hidden")
    }

    select(event){
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
                // Close dropdown and reload page to apply language
                this.dropdownTarget.classList.add("hidden")
                window.location.reload()
            })
            .catch((error) => {
                console.error("Language change error:", error)
            })
    }
}