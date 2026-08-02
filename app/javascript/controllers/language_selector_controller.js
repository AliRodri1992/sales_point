import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["dropdown", "flag"]

    toggle(event){
        event.stopPropagation()
        this.dropdownTarget.classList.toggle("hidden")
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