import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["dropdown", "flag"]

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
        this.dropdownTarget.classList.toggle("hidden")
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


        fetch("/language",
            {

                method: "PATCH",

                headers:
                    {
                        "X-CSRF-Token":
                        document.querySelector(
                            "meta[name='csrf-token']"
                        ).content,

                        "Content-Type":
                            "application/json"
                    },

                body:
                    JSON.stringify(
                        {
                            language
                        })
            })
            .then(() => {

                window.location.reload()

            })
    }
}