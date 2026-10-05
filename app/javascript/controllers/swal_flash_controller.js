import { Controller } from "@hotwired/stimulus"

// Shows a server-provided SweetAlert2 toast on page load.
// The layout renders a hidden trigger element carrying the message and icon
// as Stimulus values; connect() fires the toast once.
export default class extends Controller {
    static values = {
        message: String,
        icon: { type: String, default: "success" }
    }

    connect() {
        if (!this.messageValue) return

        window.Swal.fire({
            toast: true,
            icon: this.iconValue,
            position: "top-end",
            timer: 2600,
            showConfirmButton: false,
            timerProgressBar: true,
            title: this.messageValue
        })
    }
}
