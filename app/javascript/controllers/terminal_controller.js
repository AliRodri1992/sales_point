import { Controller } from "@hotwired/stimulus"


export default class extends Controller {


    static targets = [

        "wrapper",

        "themeDropdown",

        "password",

        "loginCard",

        "errorBanner",

        "input",

        "themeOption"

    ]



    connect() {

        this.bannerTimeout = null

        this.closeHandler =
            this.closeDropdowns.bind(this)


        document.addEventListener(
            "click",
            this.closeHandler
        )

        // Show errors if banner is visible on initial load
        if (
            this.hasErrorBannerTarget &&
            !this.errorBannerTarget.classList.contains("hidden")
        ) {
            this.showErrors()
        }

    }



    disconnect() {

        document.removeEventListener(
            "click",
            this.closeHandler
        )

    }



    toggleThemeDropdown(event) {

        event.stopPropagation()


        if(
            this.themeDropdownTarget
                .classList
                .contains("hidden")
        ){

            this.openThemeDropdown()

        } else {

            this.closeDropdowns()
        }

    }



    openThemeDropdown() {

        this.themeDropdownTarget
            .classList
            .remove("hidden")


        requestAnimationFrame(() => {

            this.themeDropdownTarget
                .classList
                .remove(
                    "opacity-0",
                    "scale-95"
                )
        })

    }



    closeDropdowns() {

        if(
            this.hasThemeDropdownTarget
        ){

            this.themeDropdownTarget
                .classList
                .add(
                    "hidden",
                    "opacity-0",
                    "scale-95"
                )
        }

    }



    togglePassword(event) {
        event.preventDefault()
        event.stopPropagation()

        const passwordField =
            event.currentTarget
                .closest(".relative")
                ?.querySelector('input[type="password"], input[type="text"]')

        if (!passwordField) return

        passwordField.type =
            passwordField.type === "password"
                ? "text"
                : "password"
    }




    selectTheme(event) {


        event.stopPropagation()


        const button =
            event.currentTarget


        const theme =
            button.dataset.theme



        this.wrapperTarget.className =
            this.wrapperTarget.className.replace(
                /theme-[a-z0-9-]+/,
                theme
            )



        this.themeOptionTargets.forEach(
            option => {

                option.classList.remove(
                    "rounded-full"
                )


                option.classList.add(
                    "rounded-lg"
                )


                option.innerHTML = ""

            }
        )



        button.classList.remove(
            "rounded-lg"
        )


        button.classList.add(
            "rounded-full"
        )



        const dot =
            document.createElement(
                "span"
            )


        dot.className =
            theme === "theme-material-school-yellow"
                ?
                "block w-1.5 h-1.5 rounded-full bg-zinc-800"
                :
                "block w-1.5 h-1.5 rounded-full bg-white"



        button.appendChild(dot)



        this.closeDropdowns()

    }





    clearErrors() {


        if(this.bannerTimeout){

            clearTimeout(
                this.bannerTimeout
            )
        }



        this.inputTargets.forEach(
            input => {

                input.style.removeProperty(
                    "box-shadow"
                )


                input.style.removeProperty(
                    "border-color"
                )

            }
        )



        if(
            this.hasErrorBannerTarget
        ){

            this.errorBannerTarget
                .classList
                .add(
                    "hidden",
                    "translate-y-2",
                    "opacity-0"
                )
        }

    }

    showErrors() {


        this.loginCardTarget.classList.add(
            "animate-shake"
        )



        setTimeout(() => {

            this.loginCardTarget.classList.remove(
                "animate-shake"
            )

        },400)




        this.inputTargets.forEach(
            input => {

                input.style.borderColor =
                    "#b71c1c"


                input.style.boxShadow =
                    "0 0 0 4px #ffcdd2"

            }
        )



        this.errorBannerTarget
            .classList
            .remove(
                "hidden",
                "translate-y-2",
                "opacity-0"
            )



        this.bannerTimeout =
            setTimeout(
                () => this.clearErrors(),
                5000
            )

    }

}